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

# --- Hardware PWM setup ---
# GPIO 18 = PWM0 on pwmchip0
PWM_CHIP = "/sys/class/pwm/pwmchip0"
PWM_CHANNEL = 0
PWM_PATH = f"{PWM_CHIP}/pwm{PWM_CHANNEL}"

# PWM frequency: 100Hz - gives full 0-100% control range
PWM_FREQUENCY = 100
PWM_PERIOD_NS = int(1_000_000_000 / PWM_FREQUENCY)  # Period in nanoseconds

# --- Temperature thresholds ---
FAN_OFF_TEMP = 37  # Below this, fan is off
MAX_TEMP = 45      # Max temp for full speed

def setup_pwm():
    """Initialize hardware PWM"""
    try:
        # Export PWM channel if not already exported
        if not os.path.exists(PWM_PATH):
            with open(f"{PWM_CHIP}/export", "w") as f:
                f.write(str(PWM_CHANNEL))
            time.sleep(0.1)  # Give it time to initialize
        
        # Set period (frequency)
        with open(f"{PWM_PATH}/period", "w") as f:
            f.write(str(PWM_PERIOD_NS))
        
        # Enable PWM
        with open(f"{PWM_PATH}/enable", "w") as f:
            f.write("1")
        
        logging.info(f"Hardware PWM initialized: {PWM_FREQUENCY}Hz")
        return True
    except Exception as e:
        logging.error(f"Failed to setup PWM: {e}")
        return False

def set_duty_cycle(duty_percent):
    """Set PWM duty cycle (0-100%)"""
    try:
        duty_ns = int((duty_percent / 100.0) * PWM_PERIOD_NS)
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

def temp_to_duty(temp):
    """Convert temperature to PWM duty cycle (rounded to integer)"""
    if temp <= FAN_OFF_TEMP:
        return 0  # Turn off fan
    elif temp >= MAX_TEMP:
        return 100  # Full speed
    else:
        # Linear interpolation between FAN_OFF_TEMP and MAX_TEMP
        duty = ((temp - FAN_OFF_TEMP) / (MAX_TEMP - FAN_OFF_TEMP)) * 100
        # Round to nearest integer
        return round(duty)

try:
    if not setup_pwm():
        logging.error("Failed to initialize PWM, exiting")
        exit(1)
    
    logging.info("Hardware PWM fan control started")
    while True:
        cpu_temp = get_cpu_temp()
        duty_cycle = temp_to_duty(cpu_temp)
        set_duty_cycle(duty_cycle)
        logging.info(f"CPU Temp: {cpu_temp:.1f}°C | PWM Duty: {duty_cycle}%")
        time.sleep(2)

except KeyboardInterrupt:
    pass

finally:
    cleanup_pwm()
    logging.info("Hardware PWM fan control stopped")

