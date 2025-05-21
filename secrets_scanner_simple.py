import os
import sys
import subprocess
from pathlib import Path
from typing import List, Set
from detect_secrets import SecretsCollection
from detect_secrets.settings import default_settings

class SimpleSecretsScanner:
    """
    A simplified secrets scanner that primarily leverages the detect-secrets library.
    
    This scanner adds custom detection rules through the detect-secrets configuration
    rather than implementing a custom plugin, making it simpler to maintain.
    """
    
    def __init__(self, 
                 directory: str = ".",
                 allow_file: str = ".secrets.baseline",
                 high_only: bool = False,
                 scan_gitignored: bool = False,
                 check_git_history: bool = False):
        """
        Initialize the scanner with the given settings.
        
        Args:
            directory: Directory to scan
            allow_file: Path to the baseline file for acceptable findings
            high_only: Whether to only report high severity findings
            scan_gitignored: Whether to scan files excluded by .gitignore
            check_git_history: Whether to check if gitignored files were previously committed
        """
        self.directory = directory
        self.allow_file = allow_file  
        self.high_only = high_only
        self.scan_gitignored = scan_gitignored
        self.check_git_history = check_git_history
        
        # Get baseline if it exists
        self.baseline = None
        if os.path.isfile(self.allow_file):
            try:
                with open(self.allow_file) as f:
                    import json
                    self.baseline = json.load(f)
                print(f"Loaded baseline from {self.allow_file}")
            except Exception as e:
                print(f"Error loading baseline: {e}")
        
        # Set up scanner
        self.secrets = SecretsCollection()
        self._setup_scanner()
    
    def _setup_scanner(self):
        """Configure the secrets scanner with appropriate settings."""
        settings = default_settings.default_settings
        
        # Custom plugin settings
        settings.plugins.base64_limit = 4.5  # Lower threshold to catch more potential base64 secrets
        settings.plugins.hex_limit = 3.0     # Lower threshold to catch more potential hex secrets
        
        # Configure plugins
        self.secrets.plugins = default_settings.get_plugins(settings)
        
        # Configure exclusions
        if not self.scan_gitignored and self._is_git_repo():
            settings.filters = settings.filters or {}
            settings.filters['is_git_ignored'] = {}
    
    def _is_git_repo(self) -> bool:
        """Check if the directory is in a Git repository."""
        try:
            result = subprocess.run(
                ["git", "-C", self.directory, "rev-parse", "--is-inside-work-tree"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False
            )
            return result.returncode == 0
        except:
            return False
    
    def scan(self):
        """
        Scan the directory for secrets.
        
        Returns:
            True if any high severity findings were found, False otherwise
        """
        print(f"Scanning {self.directory} for secrets...")
        
        # Scan files
        file_count = 0
        for root, _, files in os.walk(self.directory):
            for file in files:
                file_path = os.path.join(root, file)
                try:
                    self.secrets.scan_file(file_path)
                    file_count += 1
                except:
                    pass
        
        print(f"Scanned {file_count} files")
        
        # Generate report
        high_severity_found = self._print_report()
        
        # Create baseline on request
        if not self.baseline:
            print(f"To create a baseline file to ignore these results, run:")
            print(f"  detect-secrets scan {self.directory} > {self.allow_file}")
        
        return high_severity_found
    
    def _print_report(self) -> bool:
        """Print a report of the findings and return True if high severity findings exist."""
        # Process results
        findings = []
        high_severity_patterns = [
            'API', 'KEY', 'TOKEN', 'SECRET', 'PASSWORD', 'CREDENTIAL',
            'Private Key', 'AWS', 'DATABASE'
        ]
        
        for filename, secrets_dict in self.secrets.data.items():
            for secret_type, secrets_list in secrets_dict.items():
                for secret in secrets_list:
                    # Skip if in baseline
                    if self.baseline and self._is_in_baseline(secret):
                        continue
                    
                    # Determine severity
                    is_high = any(pattern.upper() in secret_type.upper() for pattern in high_severity_patterns)
                    
                    # Skip if high_only and not high
                    if self.high_only and not is_high:
                        continue
                    
                    findings.append({
                        'file': filename,
                        'line': secret.line_number,
                        'type': secret_type,
                        'severity': 'HIGH' if is_high else 'MEDIUM'
                    })
        
        # Print findings
        if not findings:
            print("\n✅ No secrets detected in the scanned files.")
            return False
        
        # Count high severity findings
        high_count = sum(1 for f in findings if f['severity'] == 'HIGH')
        medium_count = len(findings) - high_count
        
        print(f"\n🚨 Found {len(findings)} potential secrets:")
        print(f"  🔴 HIGH SEVERITY: {high_count}")
        print(f"  🟠 MEDIUM SEVERITY: {medium_count}")
        
        # Print details
        print("\n=== DETAILED FINDINGS ===\n")
        for finding in findings:
            severity_icon = "🔴" if finding['severity'] == 'HIGH' else "🟠"
            print(f"{severity_icon} {finding['severity']} - {finding['type']} in {finding['file']} line {finding['line']}")
        
        # Remediation advice
        print("\n=== REMEDIATION GUIDANCE ===\n")
        print("To fix these issues:")
        print("1. Remove hardcoded secrets and use environment variables instead")
        print("2. Never log or return sensitive values in responses")
        print("3. Store secrets in a secure vault or secrets manager")
        print("4. Consider any exposed secrets compromised and rotate them")
        print("\nTo ignore known false positives, create a baseline file with detect-secrets")
        
        return high_count > 0
    
    def _is_in_baseline(self, secret) -> bool:
        """Check if a secret is in the baseline."""
        if not self.baseline or 'results' not in self.baseline:
            return False
        
        for result in self.baseline['results']:
            if (result.get('filename') == secret.filename and 
                result.get('line_number') == secret.line_number and
                result.get('type') == secret.type_name):
                return True
        
        return False