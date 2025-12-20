#!/usr/bin/env python3
import time
import logging
import os

# --- Logging setup ---
logging.basicConfig(
    filename="/home/gaurav/fan_control_hwpwm.log",
    level=logging.INFO,
    format="%(asctime)s - %(message)s"
)

# --- Mode selection ---
TWO_SPEED_MODE = False  # Toggle between 2-level mode (True) and variable speed mode (False)

# --- Hardware PWM setup ---
# GPIO 18 = PWM0 on pwmchip0
PWM_CHIP = "/sys/class/pwm/pwmchip0"
PWM_CHANNEL = 0
PWM_PATH = f"{PWM_CHIP}/pwm{PWM_CHANNEL}"

# PWM frequency settings
# Variable speed mode: 100Hz - gives full 0-100% control range
# Two-speed mode: 30kHz - optimized for 50%/100% fan speeds
PWM_FREQUENCY_VARIABLE = 100
PWM_FREQUENCY_TWO_SPEED = 30000

# --- Temperature thresholds ---
FAN_OFF_TEMP = 37  # Below this, fan is off eg: 37
MAX_TEMP = 45      # Max temp for full speed eg: 45
MAX_PWM_DUTY = 50  # Cap PWM at 50% (variable speed mode only)
TEMP_HYSTERESIS = 2  # Temperature change threshold in °C to trigger speed change
MIN_FAN_ON_TIME = 30  # Minimum time (seconds) fan must stay on before turning off

# --- Two-speed mode settings ---
TWO_SPEED_LOW_DUTY = 11   # 11% duty at 30kHz = 50% fan speed
TWO_SPEED_HIGH_DUTY = 100  # 100% duty at 30kHz = 100% fan speed

def setup_pwm():
    """Initialize hardware PWM"""
    try:
        # Select frequency based on mode
        pwm_frequency = PWM_FREQUENCY_TWO_SPEED if TWO_SPEED_MODE else PWM_FREQUENCY_VARIABLE
        pwm_period_ns = int(1_000_000_000 / pwm_frequency)

        # Export PWM channel if not already exported
        if not os.path.exists(PWM_PATH):
            with open(f"{PWM_CHIP}/export", "w") as f:
                f.write(str(PWM_CHANNEL))
            time.sleep(0.1)  # Give it time to initialize

        # Set period (frequency)
        with open(f"{PWM_PATH}/period", "w") as f:
            f.write(str(pwm_period_ns))

        # Enable PWM
        with open(f"{PWM_PATH}/enable", "w") as f:
            f.write("1")

        mode_name = "Two-Speed" if TWO_SPEED_MODE else "Variable Speed"
        logging.info(f"Hardware PWM initialized: {pwm_frequency}Hz ({mode_name} mode)")
        return True
    except Exception as e:
        logging.error(f"Failed to setup PWM: {e}")
        return False

def set_duty_cycle(duty_percent):
    """Set PWM duty cycle (0-100%)"""
    try:
        # Calculate period based on mode
        pwm_frequency = PWM_FREQUENCY_TWO_SPEED if TWO_SPEED_MODE else PWM_FREQUENCY_VARIABLE
        pwm_period_ns = int(1_000_000_000 / pwm_frequency)
        duty_ns = int((duty_percent / 100.0) * pwm_period_ns)
        with open(f"{PWM_PATH}/duty_cycle", "w") as f:
            f.write(str(duty_ns))
    except Exception as e:
        logging.error(f"Failed to set duty cycle: {e}")

def cleanup_pwm():
    """Disable and unexport PWM"""
    try:
        # Set to 0 before disabling
        set_duty_cycle(0)
        time.sleep(0.1)
        
        # Disable PWM
        with open(f"{PWM_PATH}/enable", "w") as f:
            f.write("0")
        
        # Unexport
        with open(f"{PWM_CHIP}/unexport", "w") as f:
            f.write(str(PWM_CHANNEL))
        
        logging.info("Hardware PWM cleaned up")
    except Exception as e:
        logging.error(f"Failed to cleanup PWM: {e}")

def get_cpu_temp():
    """Read CPU temperature in Celsius"""
    with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
        return int(f.read()) / 1000.0

def temp_to_duty(temp, time_below_cutoff):
    """Convert temperature to PWM duty cycle

    Args:
        temp: Current CPU temperature
        time_below_cutoff: Time elapsed since temp dropped below FAN_OFF_TEMP (seconds)

    Returns:
        Duty cycle percentage (0-100)
    """
    # Check if we should turn off the fan
    if temp <= FAN_OFF_TEMP:
        # Only turn off if temp has been below cutoff for at least MIN_FAN_ON_TIME
        if time_below_cutoff >= MIN_FAN_ON_TIME:
            return 0  # Turn off fan
        # Otherwise, keep fan running at minimum speed
        if TWO_SPEED_MODE:
            return TWO_SPEED_LOW_DUTY
        else:
            return 1  # Minimum duty to keep fan running

    if TWO_SPEED_MODE:
        # Two-speed mode: 50% speed below MAX_TEMP, 100% speed at/above MAX_TEMP
        if temp >= MAX_TEMP:
            return TWO_SPEED_HIGH_DUTY  # 100% duty = 100% fan speed
        else:
            return TWO_SPEED_LOW_DUTY   # 11% duty = 50% fan speed
    else:
        # Variable speed mode: linear interpolation
        if temp >= MAX_TEMP:
            duty = 100  # Full speed calculation
        else:
            # Linear interpolation between FAN_OFF_TEMP and MAX_TEMP (0-100%)
            duty = ((temp - FAN_OFF_TEMP) / (MAX_TEMP - FAN_OFF_TEMP)) * 100

        # Cap at maximum allowed PWM duty
        duty = min(duty, MAX_PWM_DUTY)
        # Round to nearest integer
        return round(duty)

try:
    if not setup_pwm():
        logging.error("Failed to initialize PWM, exiting")
        exit(1)

    logging.info("Hardware PWM fan control started")

    # Track previous values for smoothing
    prev_duty_cycle = 0
    prev_temp = get_cpu_temp()
    temp_below_cutoff_time = None  # Track when temp dropped below FAN_OFF_TEMP

    while True:
        cpu_temp = get_cpu_temp()
        temp_change = abs(cpu_temp - prev_temp)

        # Track time below cutoff temperature
        if cpu_temp <= FAN_OFF_TEMP:
            if temp_below_cutoff_time is None:
                # Temperature just dropped below cutoff
                temp_below_cutoff_time = time.time()
            time_below_cutoff = time.time() - temp_below_cutoff_time
        else:
            # Temperature is above cutoff, reset timer
            temp_below_cutoff_time = None
            time_below_cutoff = 0

        # Only recalculate duty cycle if temperature changed significantly
        if temp_change >= TEMP_HYSTERESIS or prev_duty_cycle == 0:
            duty_cycle = temp_to_duty(cpu_temp, time_below_cutoff)

            # Only update if duty cycle actually changed
            if duty_cycle != prev_duty_cycle:
                set_duty_cycle(duty_cycle)

                # Track fan state transitions
                if prev_duty_cycle == 0 and duty_cycle > 0:
                    # Fan turning on
                    logging.info(f"CPU Temp: {cpu_temp:.1f}°C (Δ{temp_change:.1f}°C) | PWM Duty: {duty_cycle}% | Fan ON")
                elif prev_duty_cycle > 0 and duty_cycle == 0:
                    # Fan turning off
                    logging.info(f"CPU Temp: {cpu_temp:.1f}°C (Δ{temp_change:.1f}°C) | PWM Duty: {duty_cycle}% | Fan OFF (temp below cutoff for {time_below_cutoff:.1f}s)")
                else:
                    # Speed change while running
                    logging.info(f"CPU Temp: {cpu_temp:.1f}°C (Δ{temp_change:.1f}°C) | PWM Duty: {duty_cycle}%")

                prev_duty_cycle = duty_cycle
                prev_temp = cpu_temp

        time.sleep(2)

except KeyboardInterrupt:
    pass

finally:
    cleanup_pwm()
    logging.info("Hardware PWM fan control stopped")

