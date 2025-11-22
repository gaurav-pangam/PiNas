#!/usr/bin/env python3
"""
Lightweight system monitor API server for PiNAS
Uses only Python standard library - no external dependencies
"""

import http.server
import socketserver
import json
import os
import re
from urllib.parse import urlparse, parse_qs

PORT = 8080

class SystemMonitorHandler(http.server.SimpleHTTPRequestHandler):
    """Custom HTTP handler for system monitoring API"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        
        # API endpoints
        if parsed_path.path == '/api/cpu_temp':
            self.send_json(self.get_cpu_temp())
        elif parsed_path.path == '/api/cpu_freq':
            self.send_json(self.get_cpu_freq())
        elif parsed_path.path == '/api/ram':
            self.send_json(self.get_ram())
        elif parsed_path.path == '/api/network':
            self.send_json(self.get_network())
        elif parsed_path.path == '/api/tasks':
            self.send_json(self.get_tasks())
        elif parsed_path.path == '/api/fan':
            self.send_json(self.get_fan())
        elif parsed_path.path == '/api/all':
            # Combined endpoint for all data
            self.send_json({
                'cpu_temp': self.get_cpu_temp(),
                'cpu_freq': self.get_cpu_freq(),
                'ram': self.get_ram(),
                'network': self.get_network(),
                'tasks': self.get_tasks(),
                'fan': self.get_fan()
            })
        else:
            # Serve static files (index.html, etc.)
            super().do_GET()
    
    def send_json(self, data):
        """Send JSON response"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def get_cpu_temp(self):
        """Get CPU temperature"""
        try:
            # Try multiple thermal zone paths
            temp_paths = [
                '/sys/class/thermal/thermal_zone0/temp',
                '/sys/class/hwmon/hwmon0/temp1_input',
                '/sys/class/hwmon/hwmon1/temp1_input'
            ]
            
            for path in temp_paths:
                if os.path.exists(path):
                    with open(path, 'r') as f:
                        temp = int(f.read().strip()) / 1000.0
                        return {
                            'temperature': round(temp, 1),
                            'unit': 'C'
                        }
            
            return {'temperature': 0, 'unit': 'C', 'error': 'No thermal sensor found'}
        except Exception as e:
            return {'temperature': 0, 'unit': 'C', 'error': str(e)}
    
    def get_cpu_freq(self):
        """Get CPU frequency for all cores"""
        try:
            cores = []
            cpu_num = 0
            
            # Read frequency for each CPU core
            while os.path.exists(f'/sys/devices/system/cpu/cpu{cpu_num}/cpufreq/scaling_cur_freq'):
                with open(f'/sys/devices/system/cpu/cpu{cpu_num}/cpufreq/scaling_cur_freq', 'r') as f:
                    freq_khz = int(f.read().strip())
                    freq_mhz = freq_khz / 1000
                    cores.append({
                        'core': cpu_num,
                        'frequency': round(freq_mhz, 0)
                    })
                cpu_num += 1
            
            if cores:
                avg_freq = sum(c['frequency'] for c in cores) / len(cores)
                return {
                    'cores': cores,
                    'average': round(avg_freq, 0),
                    'unit': 'MHz'
                }
            else:
                return {'cores': [], 'average': 0, 'unit': 'MHz', 'error': 'No CPU freq data'}
        except Exception as e:
            return {'cores': [], 'average': 0, 'unit': 'MHz', 'error': str(e)}
    
    def get_ram(self):
        """Get RAM usage"""
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            
            # Parse meminfo
            mem_total = int(re.search(r'MemTotal:\s+(\d+)', meminfo).group(1)) / 1024  # MB
            mem_free = int(re.search(r'MemFree:\s+(\d+)', meminfo).group(1)) / 1024
            mem_available = int(re.search(r'MemAvailable:\s+(\d+)', meminfo).group(1)) / 1024
            
            mem_used = mem_total - mem_available
            mem_percent = (mem_used / mem_total) * 100
            
            return {
                'total': round(mem_total, 0),
                'used': round(mem_used, 0),
                'free': round(mem_available, 0),
                'percent': round(mem_percent, 1),
                'unit': 'MB'
            }
        except Exception as e:
            return {'total': 0, 'used': 0, 'free': 0, 'percent': 0, 'unit': 'MB', 'error': str(e)}
    
    def get_network(self):
        """Get network statistics for wlan1 and wlan0"""
        try:
            # Read network stats from /proc/net/dev
            with open('/proc/net/dev', 'r') as f:
                lines = f.readlines()

            interfaces = {}

            # Parse stats for wlan1 and wlan0
            for line in lines[2:]:  # Skip header lines
                if 'wlan1' in line or 'wlan0' in line:
                    parts = line.split()
                    iface_name = parts[0].rstrip(':')
                    rx_bytes = int(parts[1])
                    tx_bytes = int(parts[9])

                    # Convert to MB
                    rx_mb = rx_bytes / (1024 * 1024)
                    tx_mb = tx_bytes / (1024 * 1024)

                    interfaces[iface_name] = {
                        'rx_bytes': rx_bytes,
                        'tx_bytes': tx_bytes,
                        'rx_mb': round(rx_mb, 2),
                        'tx_mb': round(tx_mb, 2),
                        'rx_rate': 0,  # Will be calculated on frontend
                        'tx_rate': 0   # Will be calculated on frontend
                    }

            # Return both interfaces (wlan1 first, then wlan0)
            return {
                'wlan1': interfaces.get('wlan1', {'rx_bytes': 0, 'tx_bytes': 0, 'rx_mb': 0, 'tx_mb': 0, 'rx_rate': 0, 'tx_rate': 0}),
                'wlan0': interfaces.get('wlan0', {'rx_bytes': 0, 'tx_bytes': 0, 'rx_mb': 0, 'tx_mb': 0, 'rx_rate': 0, 'tx_rate': 0})
            }
        except Exception as e:
            return {
                'wlan1': {'rx_bytes': 0, 'tx_bytes': 0, 'rx_mb': 0, 'tx_mb': 0, 'rx_rate': 0, 'tx_rate': 0, 'error': str(e)},
                'wlan0': {'rx_bytes': 0, 'tx_bytes': 0, 'rx_mb': 0, 'tx_mb': 0, 'rx_rate': 0, 'tx_rate': 0, 'error': str(e)}
            }
    
    def get_tasks(self):
        """Get top processes by CPU usage"""
        try:
            import subprocess
            
            # Use ps to get top processes
            result = subprocess.run(
                ['ps', 'aux', '--sort=-pcpu'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            lines = result.stdout.strip().split('\n')
            tasks = []
            
            # Parse top 15 processes (skip header)
            for line in lines[1:16]:
                parts = line.split(None, 10)
                if len(parts) >= 11:
                    tasks.append({
                        'pid': parts[1],
                        'cpu': parts[2],
                        'mem': parts[3],
                        'command': parts[10][:50]  # Truncate long commands
                    })
            
            return {'tasks': tasks}
        except Exception as e:
            return {'tasks': [], 'error': str(e)}
    
    def get_fan(self):
        """Get fan speed from PWM chip"""
        try:
            # Look for PWM chip - adjust path based on your setup
            pwm_paths = [
                '/sys/class/pwm/pwmchip0/pwm0/duty_cycle',
                '/sys/class/pwm/pwmchip1/pwm0/duty_cycle',
                '/sys/class/hwmon/hwmon0/pwm1',
                '/sys/class/hwmon/hwmon1/pwm1'
            ]
            
            period_paths = [
                '/sys/class/pwm/pwmchip0/pwm0/period',
                '/sys/class/pwm/pwmchip1/pwm0/period'
            ]
            
            duty_cycle = None
            period = None
            
            # Try to read duty cycle
            for path in pwm_paths:
                if os.path.exists(path):
                    with open(path, 'r') as f:
                        duty_cycle = int(f.read().strip())
                    break
            
            # Try to read period
            for path in period_paths:
                if os.path.exists(path):
                    with open(path, 'r') as f:
                        period = int(f.read().strip())
                    break
            
            if duty_cycle is not None and period is not None and period > 0:
                duty_percent = (duty_cycle / period) * 100
                return {
                    'duty_cycle': round(duty_percent, 1),
                    'pwm_value': duty_cycle,
                    'period': period,
                    'unit': '%'
                }
            elif duty_cycle is not None:
                # If we only have duty cycle (0-255 range for hwmon)
                duty_percent = (duty_cycle / 255) * 100
                return {
                    'duty_cycle': round(duty_percent, 1),
                    'pwm_value': duty_cycle,
                    'unit': '%'
                }
            else:
                return {'duty_cycle': 0, 'pwm_value': 0, 'unit': '%', 'error': 'PWM not found'}
        except Exception as e:
            return {'duty_cycle': 0, 'pwm_value': 0, 'unit': '%', 'error': str(e)}
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        # Only log errors, not every request
        if args[1] != '200':
            super().log_message(format, *args)

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), SystemMonitorHandler) as httpd:
        print(f"🖥️  PiNAS System Monitor Server")
        print(f"📡 Serving on http://0.0.0.0:{PORT}")
        print(f"🌐 Access from: http://192.168.0.254:{PORT}")
        print(f"\nAPI Endpoints:")
        print(f"  /api/all       - All system data")
        print(f"  /api/cpu_temp  - CPU temperature")
        print(f"  /api/cpu_freq  - CPU frequency")
        print(f"  /api/ram       - RAM usage")
        print(f"  /api/network   - Network stats")
        print(f"  /api/tasks     - Top processes")
        print(f"  /api/fan       - Fan speed")
        print(f"\nPress Ctrl+C to stop\n")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n👋 Server stopped")
