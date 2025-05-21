#!/usr/bin/env python3
"""
Enhanced Python Secrets Scanner

A powerful and maintainable tool for detecting hardcoded credentials, exposed sensitive data,
and other security issues in source code.

Features:
- Detects hardcoded secrets and credentials
- Finds instances where sensitive data might be exposed through logs or responses
- Manages acceptable findings via an allowlist file
- Provides clear, actionable output sorted by severity
- Supports both loose and strict scanning modes
- Integrates with CI/CD pipelines
- Integrates with detect-secrets library for additional scanning coverage
- Provides Git history analysis to find sensitive data in previously committed files

Usage:
    python secrets_scanner.py [options]

Options:
    --mode {loose,strict}    Scanning mode, default: loose
    --verbose                Show more detailed output
    --high-only              Only fail on HIGH severity findings (good for CI/CD)
    --allowlist-file PATH    Path to acceptable findings file (default: .secrets-allowlist.yaml)
    --directory PATH         Directory to scan (default: current directory)
    --scan-gitignored        Scan files that are excluded by .gitignore
    --check-git-history      Check if gitignored files were previously committed
    --skip-detect-secrets    Skip using detect-secrets library for additional scanning
"""

import os
import sys
import re
import argparse
import fnmatch
import subprocess
import json
import yaml
from pathlib import Path
from datetime import datetime
from enum import Enum
from typing import List, Dict, Tuple, Optional, Pattern, Set, Any, Union
from functools import lru_cache


class Severity(Enum):
    """Enumeration for different severity levels of findings."""
    HIGH = "🔴 HIGH SEVERITY"
    MEDIUM = "🟠 MEDIUM SEVERITY"
    LOW = "🟡 LOW SEVERITY"


class RiskType(Enum):
    """Enumeration for different risk types."""
    HARDCODED_SECRET = "HARDCODED SECRET"
    DATA_EXPOSURE_LOGS = "DATA EXPOSURE IN LOGS"
    DATA_EXPOSURE_RESPONSE = "DATA EXPOSURE IN RESPONSE"
    SENSITIVE_CONFIG = "SENSITIVE CONFIG SECTION"


class Finding:
    """
    Class representing a secret finding.
    
    A Finding object contains all the information about a detected secret, including
    its location, content, pattern that matched it, severity, and risk type.
    """
    
    def __init__(self, file_path: str, line_number: int, 
                 line_content: str, pattern: str, 
                 severity: Severity = Severity.LOW, 
                 risk_type: RiskType = RiskType.HARDCODED_SECRET,
                 description: str = "",
                 is_gitignored: bool = False,
                 in_git_history: bool = False,
                 is_still_tracked: bool = False):
        """
        Initialize a Finding object with details about the detected secret.
        
        Args:
            file_path: Path to the file containing the secret
            line_number: Line number where the secret was found
            line_content: Content of the line containing the secret
            pattern: Pattern that matched to find this secret
            severity: Severity level of the finding
            risk_type: Type of risk this secret represents
            description: Optional description of the finding
            is_gitignored: Whether the file is gitignored
            in_git_history: Whether the file appears in Git history
            is_still_tracked: Whether the file is still tracked by Git
        """
        self.file_path = file_path
        self.line_number = line_number
        self.line_content = line_content
        self.pattern = pattern
        self.severity = severity
        self.risk_type = risk_type
        self.description = description
        self.is_gitignored = is_gitignored
        self.in_git_history = in_git_history
        self.is_still_tracked = is_still_tracked
        
        # Generate fingerprints for uniqueness and allowlisting
        self.fingerprint = f"{file_path}:{line_number}"
        self.full_fingerprint = f"{file_path}:{line_number}:{pattern}"
    
    def __str__(self) -> str:
        """Return a string representation of the finding."""
        return f"{self.severity.value} - {self.risk_type.value} in {self.file_path}:{self.line_number}"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the finding to a dictionary for serialization."""
        return {
            "file_path": self.file_path,
            "line_number": self.line_number,
            "line_content": self.line_content,
            "pattern": self.pattern,
            "severity": self.severity.name,
            "risk_type": self.risk_type.name,
            "description": self.description,
            "is_gitignored": self.is_gitignored,
            "in_git_history": self.in_git_history,
            "is_still_tracked": self.is_still_tracked,
            "fingerprint": self.fingerprint,
            "full_fingerprint": self.full_fingerprint
        }


class GitUtils:
    """
    Utility class for Git operations.
    
    Provides methods to interact with Git repositories, check if files are
    gitignored, and analyze Git history.
    """
    
    @staticmethod
    def is_git_repository(directory: str = ".") -> bool:
        """
        Check if the directory is a Git repository.
        
        Args:
            directory: Directory to check
            
        Returns:
            True if the directory is a Git repository, False otherwise
        """
        try:
            result = subprocess.run(
                ["git", "-C", directory, "rev-parse", "--is-inside-work-tree"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False
            )
            return result.returncode == 0 and result.stdout.strip() == "true"
        except Exception:
            return False
    
    @staticmethod
    def get_gitignore_patterns(directory: str = ".") -> List[str]:
        """
        Get the patterns from .gitignore file.
        
        Args:
            directory: Directory containing the .gitignore file
            
        Returns:
            List of patterns from the .gitignore file
        """
        gitignore_path = os.path.join(directory, ".gitignore")
        patterns = []
        
        if os.path.isfile(gitignore_path):
            try:
                with open(gitignore_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        patterns.append(line)
            except Exception as e:
                print(f"⚠️ Warning: Could not read .gitignore file: {e}")
        
        return patterns
    
    @staticmethod
    def is_file_gitignored(file_path: str, directory: str = ".") -> bool:
        """
        Check if a file is ignored by Git.
        
        Args:
            file_path: Path to the file to check
            directory: Directory containing the Git repository
            
        Returns:
            True if the file is gitignored, False otherwise
        """
        try:
            result = subprocess.run(
                ["git", "-C", directory, "check-ignore", "-q", file_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False
            )
            return result.returncode == 0
        except Exception:
            return False
    
    @staticmethod
    def is_file_still_tracked(file_path: str, directory: str = ".") -> bool:
        """
        Check if a file is still tracked by Git.
        
        Args:
            file_path: Path to the file to check
            directory: Directory containing the Git repository
            
        Returns:
            True if the file is still tracked, False otherwise
        """
        try:
            result = subprocess.run(
                ["git", "-C", directory, "ls-files", "--error-unmatch", file_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False
            )
            return result.returncode == 0
        except Exception:
            return False
    
    @staticmethod
    def is_file_in_git_history(file_path: str, directory: str = ".") -> bool:
        """
        Check if a file has been previously committed to Git.
        
        Args:
            file_path: Path to the file to check
            directory: Directory containing the Git repository
            
        Returns:
            True if the file is in Git history, False otherwise
        """
        try:
            rel_path = os.path.relpath(file_path, directory)
            result = subprocess.run(
                ["git", "-C", directory, "log", "--all", "--name-only", "--format=format:", "--", rel_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False
            )
            return bool(result.stdout.strip())
        except Exception as e:
            print(f"⚠️ Warning: Could not check git history for {file_path}: {e}")
            return False
    
    @staticmethod
    def get_historical_files(directory: str = ".") -> List[Tuple[str, bool]]:
        """
        Get files from Git history that are now gitignored.
        
        Args:
            directory: Directory containing the Git repository
            
        Returns:
            List of tuples containing (file_path, is_still_tracked)
        """
        if not GitUtils.is_git_repository(directory):
            return []
        
        historical_files = []
        
        try:
            # Get all files that have ever been in Git history
            result = subprocess.run(
                ["git", "-C", directory, "log", "--all", "--name-only", "--format=format:"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True
            )
            
            # Create a set of unique file paths from history
            all_historical_paths = set()
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    full_path = os.path.abspath(os.path.join(directory, line.strip()))
                    all_historical_paths.add(full_path)
            
            # Check which files are now gitignored but still exist
            for file_path in all_historical_paths:
                if not os.path.exists(file_path):
                    continue
                
                # Check if file is gitignored
                is_ignored = GitUtils.is_file_gitignored(file_path, directory)
                if is_ignored:
                    # Check if file is still tracked despite being gitignored
                    is_tracked = GitUtils.is_file_still_tracked(file_path, directory)
                    historical_files.append((file_path, is_tracked))
            
            return historical_files
            
        except Exception as e:
            print(f"⚠️ Error analyzing Git history: {e}")
            return []


class PatternManager:
    """
    Manages patterns for secret scanning.
    
    This class handles loading, compiling, and managing patterns for detecting
    secrets in various types of files.
    """
    
    def __init__(self, mode: str = "loose", pattern_file: Optional[str] = None):
        """
        Initialize the PatternManager with the given mode.
        
        Args:
            mode: Scanning mode, either "loose" or "strict"
            pattern_file: Optional path to a pattern configuration file
        """
        self.mode = mode
        
        # Load patterns from file if specified, otherwise use default patterns
        if pattern_file and os.path.exists(pattern_file):
            self._load_patterns_from_file(pattern_file)
        else:
            self._load_default_patterns()
        
        # Pre-compile patterns for efficiency
        self._compile_patterns()
    
    def _load_patterns_from_file(self, pattern_file: str) -> None:
        """
        Load patterns from a configuration file.
        
        Args:
            pattern_file: Path to the pattern configuration file
        """
        try:
            with open(pattern_file, 'r') as f:
                if pattern_file.endswith('.yaml') or pattern_file.endswith('.yml'):
                    config = yaml.safe_load(f)
                else:
                    config = json.load(f)
            
            # Extract patterns from config file
            self.loose_patterns = config.get('loose_patterns', [])
            self.strict_patterns = config.get('strict_patterns', [])
            self.additional_patterns = config.get('additional_patterns', [])
            self.override_patterns = config.get('override_patterns', [])
            self.config_patterns = config.get('config_patterns', [])
            self.exclusion_patterns = config.get('exclusion_patterns', [])
            
            # File patterns
            self.extensions = config.get('extensions', [])
            self.config_files = config.get('config_files', [])
            self.exclude_dirs = config.get('exclude_dirs', [])
            
            print(f"✓ Loaded patterns from {pattern_file}")
        except Exception as e:
            print(f"⚠️ Error loading patterns from {pattern_file}: {e}")
            print("Falling back to default patterns")
            self._load_default_patterns()
    
    def _load_default_patterns(self) -> None:
        """
        Load the default set of patterns for secret detection.
        
        This includes patterns for various modes (loose, strict), file types,
        and special patterns for configuration files.
        """
        # File extensions to scan
        self.extensions = [
            '*.env', '*.env.*', '.env', '.env.*', '*.py', '*.json', 
            '*.yaml', '*.yml', '*.ts*', '*.*js*', '*.sh*.*', '*.conf', '*rc',
            '*.ini', 'Dockerfile*', 'docker-compose*', '*.properties', '*.txt',
            '*.config', '*.cfg', '*.xml', '*.tf', '*.tfvars', '*.pem', '*.key'
        ]
        
        # Config files to pay special attention to
        self.config_files = [
            '.env', '*.env', '*.env.*', '*.ini', '*.conf', '*.cfg',
            '*.properties', '*.tfvars', '*.yaml', '*.yml', 'config.*'
        ]
        
        # Excluded directories and paths
        self.exclude_dirs = [
            '**/node_modules/**', '**/.git/**', '**/venv/**', 
            '**/__pycache__/**', '**/dist/**', '**/build/**', 
            '**/.vscode/**', '**/.idea/**'
        ]
        
        # Load patterns appropriate for the scanning mode
        # Loose mode patterns (fewer false positives)
        self.loose_patterns = [
            r"access[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"auth[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"apikey[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"client[_-]?secret[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"secret[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"Bearer\s+[A-Za-z0-9_-]+",  # Simplified JWT pattern
            r"AKIA[0-9A-Z]{16}",  # AWS access key ID
            r"sk_live_[0-9a-zA-Z]{24}",  # Stripe live key
            r"sk_test_[0-9a-zA-Z]{24}",  # Stripe test key
            r"token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"password[\"\\'=:\\s]+[A-Za-z0-9_.-]{8,}"
        ]
        
        # Additional patterns for loose mode
        self.additional_patterns = [
            # AWS Patterns
            r"aws.*access.*key.*=\s*[A-Za-z0-9/+=]{20,}",
            r"aws.*secret.*key.*=\s*[A-Za-z0-9/+=]{20,}",
            
            # Private Keys
            r"-----BEGIN.*PRIVATE KEY",
            
            # Generic API Keys/Tokens
            r"[a-zA-Z0-9_-]*:[a-zA-Z0-9_-]+@[a-zA-Z0-9]+",
            r"eyJ[A-Za-z0-9_-]{20,}",  # JWT Tokens
            r"gh[pousr]_[A-Za-z0-9_]{20,}",  # GitHub Tokens
            
            # Cloud Service Provider Patterns
            r"AIza[0-9A-Za-z_-]{30,}",  # Google API Key
            r"ya29\.[0-9A-Za-z_-]+",  # Google OAuth
            
            # Service-specific credentials
            r"client_id\s*=\s*[a-zA-Z0-9._-]+",          # Client IDs
            r"client_secret\s*=\s*[a-zA-Z0-9._-]+",      # Client secrets
            r"api_key\s*=\s*[a-zA-Z0-9._-]+",            # API keys
            r"access_token\s*=\s*[a-zA-Z0-9._-]+",       # Access tokens
            
            # Database Connection Strings
            r"postgres(ql)?://[^:]+:[^@]+@[^/]+",  # PostgreSQL connection
            r"mysql://[^:]+:[^@]+@[^/]+",         # MySQL connection
            r"mongodb(\+srv)?://[^:]+:[^@]+@[^/]+",  # MongoDB connection
            r"redis://[^:]+:[^@]+@.+",               # Redis connection
            r"DATABASE_URL\s*=\s*.+:.+@.+",        # Generic database URL
            
            # Payment Service Patterns
            r"sk_live_[0-9a-zA-Z]{24}",  # Stripe Secret Key
            r"rk_live_[0-9a-zA-Z]{24}",  # Stripe Restricted Key
            
            # More specific token formats
            r"xox[baprs]-[0-9a-zA-Z]{10,}",  # Slack API Token
            r"T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8}/[a-zA-Z0-9_]{24}",  # Slack Webhook
            
            # Common password patterns
            r"password\s*=\s*[^\s]+",  # Generic password assignment
            r"pwd\s*=\s*[^\s]+",       # Abbreviated password
            r"pass\s*=\s*[^\s]+",      # Another common password variable
            
            # Dangerous logging patterns
            r"console\.log.*pass",
            r"console\.log.*password",
            r"console\.log.*secret",
            r"console\.log.*token",
            r"console\.log.*key",
            r"console\.log.*cred",
            r"print.*pass",
            r"print.*password",
            r"print.*secret",
            r"print.*token",
            r"print.*key",
            r"echo.*password",
            r"echo.*secret",
            r"echo.*token",
            r"echo.*key",
            
            # Return/response exposure patterns
            r"return.*password",
            r"return.*token",
            r"return.*secret",
            r"return.*key",
            r"res\.send.*password",
            r"res\.send.*token",
            r"res\.send.*secret",
            r"res\.json.*password",
            r"res\.json.*token",
            r"res\.json.*secret",
            
            # INI section headers
            r"\[.*api.*\]",
            r"\[.*key.*\]",
            r"\[.*secret.*\]",
            r"\[.*credential.*\]",
            r"\[.*auth.*\]"
        ]
        
        # Strict patterns (broader, more false positives)
        self.strict_patterns = [
            r'token',
            r'secret',
            r'password',
            r'auth',
            r'client',
            r'api[_-]?key',
            r'session',
            r'pass',
            r'pwd',
            r'credential'
        ]
        
        # Override patterns (always HIGH severity)
        self.override_patterns = [
            # Client secrets
            r"client_secret\s*=\s*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            r"client_secret\s*=\s*[a-zA-Z0-9._-]+",
            
            # Actual tokens
            r"token\s*=\s*[\"''][0-9a-zA-Z._=/-]{16,}[\"'']",
            r"secret\s*=\s*[\"''][0-9a-zA-Z._=/-]{16,}[\"'']",
            r"password\s*=\s*[\"''][0-9a-zA-Z._=/-]{8,}[\"'']",
            r"access_key\s*=\s*[\"''][0-9a-zA-Z]{16,}[\"'']",
            
            # Database connection strings and credentials
            r"DATABASE_URL\s*=\s*[^=]+(:|%3A)[^=]+(@|%40)",
            r"(POSTGRES|SQL|DB|MYSQL|MONGO)(_)?PASS(WORD)?\s*=\s*[^\s$]+",
            
            # Password patterns in config/env files
            r"PASSWORD\s*=\s*[^\s$]+",
            r"PASS\s*=\s*[^\s$]+",
            r"PWD\s*=\s*[^\s$]+"
        ]
        
        # Config-specific patterns
        self.config_patterns = [
            r"password\s*=\s*[^\s$]+",
            r"secret\s*=\s*[^\s$]+",
            r"key\s*=\s*[^\s$]+",
            r"token\s*=\s*[^\s$]+",
            r"auth\s*=\s*[^\s$]+",
            r"credential\s*=\s*[^\s$]+",
            r"api[_-]?key\s*=\s*[^\s$]+",
            r"database\s*=\s*[^\s$]+",
            r"user\s*=\s*[^\s$]+",
            r"pass\s*=\s*[^\s$]+",
            r"pwd\s*=\s*[^\s$]+"
        ]
        
        # Exclusion patterns to reduce false positives
        self.exclusion_patterns = [
            # Exclude simple debug statements
            r"console\.log\([\"''][^\"\'']*[\"'']\)",
            
            # Exclude test or example code
            r"example|sample|mock|dummy|test|placeholder|template|default",
            
            # Exclude comments
            r"\s*//|\s*#",
            
            # Exclude TODOs and FIXMEs
            r"TODO|FIXME",
            
            # Exclude development URLs
            r"github\.com|localhost|127\.0\.1",
            
            # Exclude docstrings about tokens
            r"token management|token information|token endpoints",
            
            # Exclude common variable assignments without actual secrets
            r"token\s*=\s*\w+\.json",
            r"token\s*=\s*\w+\.copy",
            
            # Exclude function parameters that reference tokens
            r"refresh_token=refresh_token",
            
            # Exclude local host ips
            r"0.0.0.0"
        ]
    
    def _compile_patterns(self) -> None:
        """
        Pre-compile regex patterns for efficiency.
        
        This method compiles the regular expressions used for scanning to improve
        performance when scanning large codebases.
        """
        # Determine which patterns to use based on mode
        if self.mode == "strict":
            patterns_to_use = self.strict_patterns
        else:  # loose mode
            patterns_to_use = self.loose_patterns + self.additional_patterns
        
        # Compile main patterns
        self.compiled_patterns = []
        for pattern in patterns_to_use:
            try:
                self.compiled_patterns.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile pattern '{pattern}': {e}")
                # Try a simplified version
                try:
                    simplified = pattern.replace('\\s+', '\\s*').replace('{10,}', '{10,100}')
                    self.compiled_patterns.append((re.compile(simplified, re.IGNORECASE), pattern))
                    print(f"  ✓ Using simplified pattern instead: '{simplified}'")
                except re.error:
                    print(f"  ❌ Still couldn't compile pattern. Skipping: {pattern}")
        
        # Compile override patterns
        self.compiled_overrides = []
        for pattern in self.override_patterns:
            try:
                self.compiled_overrides.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile override pattern '{pattern}': {e}")
        
        # Compile config-specific patterns
        self.compiled_config_patterns = []
        for pattern in self.config_patterns:
            try:
                self.compiled_config_patterns.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile config pattern '{pattern}': {e}")
        
        # Compile exclusion patterns
        self.compiled_exclusions = []
        for pattern in self.exclusion_patterns:
            try:
                self.compiled_exclusions.append(re.compile(pattern, re.IGNORECASE))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile exclusion pattern '{pattern}': {e}")
    
    def should_scan_file(self, file_path: str, exclude_dirs: Optional[List[str]] = None) -> bool:
        """
        Check if a file should be scanned based on extensions and exclusions.
        
        Args:
            file_path: Path to the file to check
            exclude_dirs: Optional additional directories to exclude
            
        Returns:
            True if the file should be scanned, False otherwise
        """
        # Check exclusions first
        for pattern in self.exclude_dirs:
            if fnmatch.fnmatch(file_path, pattern):
                return False
        
        # Check additional exclusions if provided
        if exclude_dirs:
            for pattern in exclude_dirs:
                if fnmatch.fnmatch(file_path, pattern):
                    return False
        
        # Check if file matches any of our extensions
        file_name = os.path.basename(file_path)
        return any(fnmatch.fnmatch(file_name, ext) for ext in self.extensions)
    
    def is_config_file(self, file_path: str) -> bool:
        """
        Check if a file is a configuration file.
        
        Args:
            file_path: Path to the file to check
            
        Returns:
            True if the file is a configuration file, False otherwise
        """
        file_name = os.path.basename(file_path)
        file_ext = os.path.splitext(file_path)[1].lower()
        
        return (file_ext in ['.ini', '.conf', '.env', '.cfg', '.yaml', '.yml', '.properties', '.tfvars'] or 
                any(fnmatch.fnmatch(file_name, pattern) for pattern in self.config_files))
    
    def should_exclude_line(self, line: str) -> bool:
        """
        Check if a line should be excluded from scanning.
        
        Args:
            line: The line to check
            
        Returns:
            True if the line should be excluded, False otherwise
        """
        for pattern in self.compiled_exclusions:
            if pattern.search(line):
                return True
        return False


class AllowlistManager:
    """
    Manages the allowlist of acceptable findings.
    
    This class handles loading, checking, and updating the allowlist of
    findings that should be ignored during scanning.
    """
    
    def __init__(self, allowlist_file: str = ".secrets-allowlist.yaml"):
        """
        Initialize the AllowlistManager with the given allowlist file.
        
        Args:
            allowlist_file: Path to the allowlist file
        """
        self.allowlist_file = allowlist_file
        self.allowlist = self._load_allowlist()
    
    def _load_allowlist(self) -> Dict[str, Dict[str, str]]:
        """
        Load the allowlist from the allowlist file.
        
        Returns:
            Dictionary mapping fingerprints to information about the allowlisted finding
        """
        if not os.path.exists(self.allowlist_file):
            print(f"ℹ️ No allowlist file found at {self.allowlist_file}")
            return {}
        
        try:
            with open(self.allowlist_file, 'r') as f:
                if self.allowlist_file.endswith('.yaml') or self.allowlist_file.endswith('.yml'):
                    allowlist = yaml.safe_load(f) or {}
                elif self.allowlist_file.endswith('.json'):
                    allowlist = json.load(f)
                else:
                    # Simple text file format
                    allowlist = {}
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        allowlist[line] = {"reason": "Preapproved"}
            
            print(f"✓ Loaded {len(allowlist)} allowlisted findings")
            return allowlist
        except Exception as e:
            print(f"⚠️ Warning: Could not read allowlist file: {e}")
            return {}
    
    def is_allowlisted(self, finding: Finding) -> bool:
        """
        Check if a finding is in the allowlist.
        
        Args:
            finding: The finding to check
            
        Returns:
            True if the finding is allowlisted, False otherwise
        """
        # Check exact fingerprint
        if finding.fingerprint in self.allowlist:
            return True
        
        # Check full fingerprint
        if finding.full_fingerprint in self.allowlist:
            return True
        
        # Check pattern-based fingerprints
        for pattern, info in self.allowlist.items():
            if '*' in pattern:
                # Convert glob pattern to regex
                regex_pattern = pattern.replace('*', '.*')
                if re.match(regex_pattern, finding.fingerprint) or re.match(regex_pattern, finding.full_fingerprint):
                    return True
        
        return False
    
    def add_finding_to_allowlist(self, finding: Finding, reason: str = "", added_by: str = "") -> bool:
        """
        Add a finding to the allowlist.
        
        Args:
            finding: The finding to add
            reason: Reason for allowlisting
            added_by: User who added the finding
            
        Returns:
            True if the finding was added, False otherwise
        """
        if not reason:
            reason = "Manually allowlisted"
        
        if not added_by:
            added_by = os.getenv("USER", "unknown")
        
        # Add to allowlist
        self.allowlist[finding.full_fingerprint] = {
            "reason": reason,
            "added_by": added_by,
            "date_added": datetime.now().isoformat()
        }
        
        # Save allowlist
        try:
            with open(self.allowlist_file, 'w') as f:
                if self.allowlist_file.endswith('.yaml') or self.allowlist_file.endswith('.yml'):
                    yaml.dump(self.allowlist, f, default_flow_style=False)
                elif self.allowlist_file.endswith('.json'):
                    json.dump(self.allowlist, f, indent=2)
                else:
                    # Simple text file format
                    for fingerprint, info in self.allowlist.items():
                        reason_str = f" # {info.get('reason')}" if 'reason' in info else ""
                        f.write(f"{fingerprint}{reason_str}\n")
            
            print(f"✓ Added finding to allowlist: {finding.full_fingerprint}")
            return True
        except Exception as e:
            print(f"⚠️ Error saving allowlist: {e}")
            return False
    
    def generate_allowlist_from_findings(self, findings: List[Finding], output_file: str) -> bool:
        """
        Generate an allowlist file from a list of findings.
        
        Args:
            findings: List of findings to add to the allowlist
            output_file: Path to the output file
            
        Returns:
            True if the allowlist was generated, False otherwise
        """
        try:
            allowlist = {}
            for finding in findings:
                allowlist[finding.full_fingerprint] = {
                    "reason": "TO REVIEW",
                    "added_by": os.getenv("USER", "unknown"),
                    "date_added": datetime.now().isoformat()
                }
            
            with open(output_file, 'w') as f:
                if output_file.endswith('.yaml') or output_file.endswith('.yml'):
                    yaml.dump(allowlist, f, default_flow_style=False)
                elif output_file.endswith('.json'):
                    json.dump(allowlist, f, indent=2)
                else:
                    # Simple text file format
                    for fingerprint in allowlist:
                        f.write(f"{fingerprint}\n")
            
            print(f"✓ Generated allowlist file: {output_file}")
            return True
        except Exception as e:
            print(f"⚠️ Error generating allowlist: {e}")
            return False


class GitHistoryScanner:
    """
    Scanner for Git history to find sensitive data in previously committed files.
    
    This class handles scanning files that appear in Git history but may now be
    gitignored, to identify potentially leaked secrets.
    """
    
    def __init__(self, scanner, repo_path="."):
        """
        Initialize the GitHistoryScanner.
        
        Args:
            scanner: The main SecretsScanner instance
            repo_path: Path to the Git repository
        """
        self.scanner = scanner
        self.repo_path = repo_path
        self.is_git_repo = self._check_is_git_repo()
    
    def _check_is_git_repo(self) -> bool:
        """
        Check if the directory is a Git repository.
        
        Returns:
            True if the directory is a Git repository, False otherwise
        """
        return GitUtils.is_git_repository(self.repo_path)
    
    def scan_historical_files(self, deep_scan: bool = False) -> List[Finding]:
        """
        Scan files from Git history for secrets.
        
        Args:
            deep_scan: If True, perform a more thorough scan of Git history
            
        Returns:
            List of findings in historical files
        """
        if not self.is_git_repo:
            print("⚠️ Not a Git repository. Skipping Git history scan.")
            return []
        
        findings = []
        
        # Get files from Git history that are now gitignored
        historical_files = GitUtils.get_historical_files(self.repo_path)
        
        if historical_files:
            print(f"🔍 Found {len(historical_files)} historical files to scan")
            
            # Group files by tracking status
            tracked_files = [(path, True) for path, tracked in historical_files if tracked]
            untracked_files = [(path, False) for path, tracked in historical_files if not tracked]
            
            if tracked_files:
                print(f"⚠️ {len(tracked_files)} files are gitignored but still tracked (high risk)")
            
            if untracked_files:
                print(f"ℹ️ {len(untracked_files)} files are gitignored and not tracked")
            
            # Scan all historical files
            for file_path, is_tracked in historical_files:
                # Check if file should be scanned based on patterns
                if not self.scanner.pattern_manager.should_scan_file(file_path):
                    continue
                
                print(f"  Scanning historical file: {file_path}" +
                      (" (still tracked)" if is_tracked else ""))
                
                # Scan the file for secrets
                file_findings = self.scanner.scan_file(file_path)
                
                # Tag findings appropriately
                for finding in file_findings:
                    finding.is_gitignored = True
                    finding.in_git_history = True
                    finding.is_still_tracked = is_tracked
                    
                    # Increase severity for tracked historical files
                    if is_tracked and finding.severity != Severity.HIGH:
                        finding.severity = Severity.HIGH
                        finding.description += " (Gitignored but still tracked in Git)"
                
                findings.extend(file_findings)
        
        # Optionally perform a deeper scan of Git objects
        if deep_scan:
            print("🔍 Performing deep scan of Git history...")
            blob_findings = self._scan_git_objects()
            findings.extend(blob_findings)
        
        return findings
    
    def _scan_git_objects(self) -> List[Finding]:
        """
        Scan Git objects (blobs) for secrets.
        
        This performs a more thorough scan by examining Git objects directly,
        rather than just current files.
        
        Returns:
            List of findings in Git objects
        """
        if not self.is_git_repo:
            return []
        
        findings = []
        
        try:
            # Get all blob objects from Git (limit to reasonable sample size)
            result = subprocess.run(
                ["git", "rev-list", "--objects", "--all", "--max-count=1000"],
                cwd=self.repo_path, stdout=subprocess.PIPE, text=True, check=True
            )
            
            # Process each line to extract blob and path
            blob_paths = {}
            for line in result.stdout.strip().split('\n'):
                parts = line.strip().split(maxsplit=1)
                if len(parts) == 2:
                    blob_hash, path = parts
                    # Only keep files we'd normally scan
                    if self.scanner.pattern_manager.should_scan_file(path):
                        blob_paths[blob_hash] = path
            
            if blob_paths:
                print(f"🔍 Deep scanning {len(blob_paths)} Git objects...")
                
                # Sample a reasonable number of blobs to scan
                import random
                sample_size = min(100, len(blob_paths))
                samples = random.sample(list(blob_paths.items()), sample_size) if sample_size > 0 else []
                
                for blob_hash, path in samples:
                    # Get blob content
                    cat_file = subprocess.run(
                        ["git", "cat-file", "-p", blob_hash],
                        cwd=self.repo_path, stdout=subprocess.PIPE, text=True, check=True
                    )
                    content = cat_file.stdout
                    
                    # Scan the content with the same pattern logic
                    for i, line in enumerate(content.split('\n'), 1):
                        # Skip if line should be excluded
                        if self.scanner.pattern_manager.should_exclude_line(line):
                            continue
                        
                        # Use the same pattern scanning logic as the main scanner
                        for compiled_pattern, pattern_str in self.scanner.pattern_manager.compiled_patterns:
                            match = compiled_pattern.search(line)
                            if match:
                                # All Git history findings are HIGH severity
                                severity = Severity.HIGH
                                risk_type = self.scanner._determine_risk_type(line)
                                
                                finding = Finding(
                                    file_path=f"[Git blob] {path}",
                                    line_number=i,
                                    line_content=line.strip(),
                                    pattern=pattern_str,
                                    severity=severity,
                                    risk_type=risk_type,
                                    description="Found in Git history blob",
                                    is_gitignored=False,
                                    in_git_history=True
                                )
                                
                                # Skip if allowlisted
                                if self.scanner.allowlist_manager.is_allowlisted(finding):
                                    continue
                                
                                findings.append(finding)
            
            return findings
            
        except Exception as e:
            print(f"⚠️ Error scanning Git objects: {e}")
            return []


class SecretsScanner:
    """
    Main secrets scanner class.
    
    This class orchestrates the entire scanning process, including pattern matching,
    Git history analysis, and integration with detect-secrets.
    """
    
    def __init__(self, mode: str = "loose", verbose: bool = False, 
                high_only: bool = False, allowlist_file: str = ".secrets-allowlist.yaml",
                directory: str = ".", scan_gitignored: bool = False,
                check_git_history: bool = False, deep_scan: bool = False,
                use_detect_secrets: bool = True, pattern_file: Optional[str] = None):
        """
        Initialize the SecretsScanner with the given settings.
        
        Args:
            mode: Scanning mode, either "loose" or "strict"
            verbose: Whether to show verbose output
            high_only: Whether to only report high severity findings
            allowlist_file: Path to the allowlist file
            directory: Directory to scan
            scan_gitignored: Whether to scan gitignored files
            check_git_history: Whether to check Git history
            deep_scan: Whether to perform a deep scan of Git history
            use_detect_secrets: Whether to use the detect-secrets library
            pattern_file: Optional path to a pattern configuration file
        """
        self.mode = mode
        self.verbose = verbose
        self.high_only = high_only
        self.allowlist_file = allowlist_file
        self.directory = directory
        self.scan_gitignored = scan_gitignored
        self.check_git_history = check_git_history
        self.deep_scan = deep_scan
        self.use_detect_secrets = use_detect_secrets
        self.findings = []
        
        # Initialize pattern manager
        self.pattern_manager = PatternManager(mode, pattern_file)
        
        # Initialize allowlist manager
        self.allowlist_manager = AllowlistManager(allowlist_file)
        
        # Check if detect-secrets is available
        if self.use_detect_secrets:
            self._check_detect_secrets()
        
        # Check if we're in a Git repository
        self.is_git_repo = GitUtils.is_git_repository(directory)
        if self.check_git_history and not self.is_git_repo:
            print("⚠️ Warning: --check-git-history specified but not in a Git repository. Feature will be disabled.")
            self.check_git_history = False
    
    def _check_detect_secrets(self) -> None:
        """
        Check if detect-secrets library is available and configured.
        
        This method attempts to import the detect-secrets library and sets
        the use_detect_secrets flag accordingly.
        """
        try:
            import detect_secrets
            print("✓ detect-secrets library found and will be used for additional scanning")
        except ImportError as e:
            print(f"⚠️ Warning: detect-secrets library not found: {e}")
            print("   Install with: pip install detect-secrets")
            self.use_detect_secrets = False
    
    def _determine_risk_type(self, line: str) -> RiskType:
        """
        Determine the risk type based on line content.
        
        Args:
            line: The line to analyze
            
        Returns:
            The risk type of the line
        """
        if any(term in line.lower() for term in ["console.", "print", "echo", "log."]):
            return RiskType.DATA_EXPOSURE_LOGS
        elif any(term in line.lower() for term in ["return", "res.", "response"]):
            return RiskType.DATA_EXPOSURE_RESPONSE
        elif "[" in line and "]" in line:
            return RiskType.SENSITIVE_CONFIG
        else:
            return RiskType.HARDCODED_SECRET
    
    def _determine_severity_and_risk(self, file_path: str, line_content: str, matching_pattern: str) -> Tuple[Severity, RiskType]:
        """
        Determine the severity and risk type of a finding.
        
        Args:
            file_path: Path to the file containing the finding
            line_content: Content of the line containing the finding
            matching_pattern: Pattern that matched the finding
            
        Returns:
            Tuple of (Severity, RiskType)
        """
        # Start with risk type determination
        risk_type = self._determine_risk_type(line_content)
        
        # Check if this is an override pattern (always HIGH)
        for compiled_pattern, pattern in self.pattern_manager.compiled_overrides:
            if compiled_pattern.search(line_content):
                return Severity.HIGH, risk_type
        
        # Determine file type - config files have higher severity
        is_config_file = self.pattern_manager.is_config_file(file_path)
        
        # High severity - actual value assignments in config files
        if is_config_file:
            sensitive_terms = ["client_id", "client_secret", "api_key", "password", "token", "access_key", 
                           "DATABASE_URL", "POSTGRES_PASSWORD", "secret", "key", "auth", "credential"]
            if any(term.lower() in line_content.lower() and "=" in line_content for term in sensitive_terms):
                return Severity.HIGH, risk_type
        
        # High severity for specific patterns in logging
        if ("console." in line_content.lower() or "print" in line_content.lower() or "echo" in line_content.lower() or "log." in line_content.lower()) and any(
            term in line_content.lower() for term in ["pass", "secret", "token", "api", "cred"]):
            return Severity.HIGH, risk_type
        
        # Medium severity - possible hardcoded values in code
        if re.search(r'(=|:)\s*["\'][0-9a-zA-Z._=/-]{16,}["\']', line_content):
            return Severity.MEDIUM, risk_type
        
        # Database credentials in any file
        if any(db in line_content.lower() for db in ["postgres", "sql", "mysql", "mongo"]) and any(term in line_content.lower() for term in ["password", "pass", "pwd"]):
            return Severity.HIGH, risk_type
        
        # Password with special chars
        if re.search(r'(password|pass|pwd)\s*=', line_content.lower()) and any(char in line_content for char in ['!', '@', '#', '$', '%', '^', '&', '*']):
            return Severity.HIGH, risk_type
        
        # FORCE HIGH for client_id/client_secret
        if "client_id" in line_content.lower() or "client_secret" in line_content.lower():
            return Severity.HIGH, risk_type
        
        # Low severity (default)
        return Severity.LOW, risk_type
    
    def _get_line_content(self, file_path: str, line_number: int) -> str:
        """
        Get the content of a specific line in a file.
        
        Args:
            file_path: Path to the file
            line_number: Line number to get
            
        Returns:
            The content of the line
        """
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for i, line in enumerate(f, 1):
                    if i == line_number:
                        return line.strip()
            return ""
        except Exception:
            return "<could not read line>"
    
    def _get_context_lines(self, file_path: str, line_number: int, context: int = 2) -> List[str]:
        """
        Get context lines around a line in a file.
        
        Args:
            file_path: Path to the file
            line_number: Line number to get context around
            context: Number of context lines to get
            
        Returns:
            List of context lines
        """
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                
            start = max(0, line_number - context - 1)
            end = min(len(lines), line_number + context)
            
            return lines[start:end]
        except Exception as e:
            return [f"[Could not read file: {e}]"]
    
    def _collect_files_to_scan(self) -> List[str]:
        """
        Collect all files that should be scanned.
        
        Returns:
            List of file paths to scan
        """
        files_to_scan = []
        gitignored_files = []
        
        # Walk the directory and collect files
        for root, _, files in os.walk(self.directory):
            for file in files:
                file_path = os.path.join(root, file)
                
                # Check if file should be scanned based on patterns
                if not self.pattern_manager.should_scan_file(file_path):
                    continue
                
                # Check if file is gitignored
                is_gitignored = False
                if self.is_git_repo:
                    is_gitignored = GitUtils.is_file_gitignored(file_path, self.directory)
                
                # Skip gitignored files if not scanning them
                if is_gitignored:
                    if self.scan_gitignored:
                        gitignored_files.append(file_path)
                    else:
                        continue
                else:
                    files_to_scan.append(file_path)
        
        # Add gitignored files to scan list if requested
        if self.scan_gitignored and gitignored_files:
            files_to_scan.extend(gitignored_files)
            print(f"🔎 Will scan {len(files_to_scan)} files ({len(gitignored_files)} gitignored)")
        else:
            print(f"🔎 Will scan {len(files_to_scan)} files")
        
        return files_to_scan
    
    def scan_file(self, file_path: str) -> List[Finding]:
        """
        Scan a single file for secrets.
        
        Args:
            file_path: Path to the file to scan
            
        Returns:
            List of findings in the file
        """
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for i, line in enumerate(f, 1):
                    # Skip if line should be excluded
                    if self.pattern_manager.should_exclude_line(line):
                        continue
                    
                    # First check override patterns - they always get HIGH severity
                    for compiled_pattern, pattern_str in self.pattern_manager.compiled_overrides:
                        match = compiled_pattern.search(line)
                        if match:
                            # Determine severity and risk
                            severity, risk_type = self._determine_severity_and_risk(file_path, line, pattern_str)
                            
                            # Create finding
                            finding = Finding(
                                file_path=file_path,
                                line_number=i,
                                line_content=line.strip(),
                                pattern=pattern_str,
                                severity=severity,
                                risk_type=risk_type,
                                description=f"Override pattern: {pattern_str}"
                            )
                            
                            # Skip if allowlisted
                            if self.allowlist_manager.is_allowlisted(finding):
                                if self.verbose:
                                    print(f"  → Allowlisted finding: {finding.file_path}:{finding.line_number}")
                                continue
                            
                            # Skip if high-only mode and not high severity
                            if self.high_only and finding.severity != Severity.HIGH:
                                continue
                            
                            findings.append(finding)
                    
                    # Now check regular patterns
                    for compiled_pattern, pattern_str in self.pattern_manager.compiled_patterns:
                        match = compiled_pattern.search(line)
                        if match:
                            # Determine severity and risk
                            severity, risk_type = self._determine_severity_and_risk(file_path, line, pattern_str)
                            
                            # Create finding
                            finding = Finding(
                                file_path=file_path,
                                line_number=i,
                                line_content=line.strip(),
                                pattern=pattern_str,
                                severity=severity,
                                risk_type=risk_type
                            )
                            
                            # Skip if allowlisted
                            if self.allowlist_manager.is_allowlisted(finding):
                                if self.verbose:
                                    print(f"  → Allowlisted finding: {finding.file_path}:{finding.line_number}")
                                continue
                            
                            # Skip if high-only mode and not high severity
                            if self.high_only and finding.severity != Severity.HIGH:
                                continue
                            
                            findings.append(finding)
                    
                    # If this is a config file, also check config-specific patterns
                    if self.pattern_manager.is_config_file(file_path):
                        for compiled_pattern, pattern_str in self.pattern_manager.compiled_config_patterns:
                            match = compiled_pattern.search(line)
                            if match:
                                # Config files usually have higher severity
                                severity = Severity.HIGH
                                risk_type = RiskType.SENSITIVE_CONFIG
                                
                                # Create finding
                                finding = Finding(
                                    file_path=file_path,
                                    line_number=i,
                                    line_content=line.strip(),
                                    pattern=pattern_str,
                                    severity=severity,
                                    risk_type=risk_type,
                                    description="Sensitive config pattern"
                                )
                                
                                # Skip if allowlisted
                                if self.allowlist_manager.is_allowlisted(finding):
                                    if self.verbose:
                                        print(f"  → Allowlisted finding: {finding.file_path}:{finding.line_number}")
                                    continue
                                
                                # Skip if high-only mode and not high severity
                                if self.high_only and severity != Severity.HIGH:
                                    continue
                                
                                findings.append(finding)
        except Exception as e:
            print(f"⚠️ Warning: Could not scan file {file_path}: {e}")
        
        return findings
    
    def _run_detect_secrets_scan(self, files_to_scan: List[str]) -> List[Finding]:
        """
        Run a scan using detect-secrets library for additional pattern coverage.
        
        Args:
            files_to_scan: List of file paths to scan
            
        Returns:
            List of findings from detect-secrets
        """
        if not self.use_detect_secrets:
            return []
        
        try:
            # Import required detect-secrets components
            from detect_secrets import SecretsCollection
            from detect_secrets.settings import transient_settings
            
            print("🔍 Running detect-secrets scanner for additional coverage")
            
            # Configure the plugins with proper settings
            plugins_config = [
                # Structured secrets detectors
                {'name': 'AWSKeyDetector'},
                {'name': 'AzureStorageKeyDetector'},
                {'name': 'BasicAuthDetector'},
                {'name': 'CloudantDetector'},
                {'name': 'DiscordBotTokenDetector'},
                {'name': 'GitHubTokenDetector'},
                {'name': 'GitLabTokenDetector'},
                {'name': 'JwtTokenDetector'},
                {'name': 'MailchimpDetector'},
                {'name': 'NpmDetector'},
                {'name': 'OpenAIDetector'},
                {'name': 'PrivateKeyDetector'},
                {'name': 'PypiTokenDetector'},
                {'name': 'SendGridDetector'},
                {'name': 'SlackDetector'},
                {'name': 'SoftlayerDetector'},
                {'name': 'SquareOAuthDetector'},
                {'name': 'StripeDetector'},
                {'name': 'TelegramBotTokenDetector'},
                {'name': 'TwilioKeyDetector'},
                
                # Entropy-based detectors with configured limits
                {'name': 'Base64HighEntropyString', 'limit': 4.5},
                {'name': 'HexHighEntropyString', 'limit': 3.0},
                
                # Keyword-based detector
                {'name': 'KeywordDetector'}
            ]
            
            # Create the configuration dictionary
            config = {
                'plugins_used': plugins_config
            }
            
            findings = []
            
            # Use transient_settings to configure the plugins
            with transient_settings(config):
                # Create a SecretsCollection to store detected secrets
                secrets = SecretsCollection()
                
                # Scan each file
                for file_idx, file_path in enumerate(files_to_scan):
                    if self.verbose and file_idx % 50 == 0:
                        print(f"  [{file_idx+1}/{len(files_to_scan)}] detect-secrets scanning: {file_path}")
                    
                    try:
                        # Scan the file
                        secrets.scan_file(file_path)
                    except Exception as e:
                        if self.verbose:
                            print(f"  ⚠️ detect-secrets error scanning {file_path}: {e}")
                
                # Based on the secrets_collection.py source code, SecretsCollection has a 'files' property 
                # (defined via __iter__) and we can access the set of secrets for a file using secrets[filename]
                try:
                    for filename in secrets.files:
                        # Process each secret in the file
                        for secret in secrets[filename]:
                            try:
                                # Get line content
                                line_number = secret.line_number  # Adjust for 0-based index
                                line_content = self._get_line_content(filename, line_number)
                                
                                # Get the secret type
                                secret_type = getattr(secret, 'type', 'Unknown')
                                
                                # Determine severity (most detect-secrets findings are HIGH)
                                severity = Severity.HIGH
                                
                                # Check for lower severity based on context
                                if any(term in line_content.lower() for term in ["test", "example", "sample", "mock"]):
                                    severity = Severity.MEDIUM
                                
                                # Determine if file is gitignored
                                is_gitignored = False
                                if self.is_git_repo:
                                    is_gitignored = GitUtils.is_file_gitignored(filename, self.directory)
                                
                                # Create a finding
                                finding = Finding(
                                    file_path=filename,
                                    line_number=line_number,
                                    line_content=line_content,
                                    pattern=f"detect-secrets:{secret_type}",
                                    severity=severity,
                                    risk_type=self._determine_risk_type(line_content),
                                    description=f"Secret detected by detect-secrets: {secret_type}",
                                    is_gitignored=is_gitignored
                                )
                                
                                # Skip if allowlisted
                                if self.allowlist_manager.is_allowlisted(finding):
                                    if self.verbose:
                                        print(f"  → Allowlisted finding: {finding.file_path}:{finding.line_number}")
                                    continue
                                
                                # Skip if high-only mode and not high severity
                                if self.high_only and severity != Severity.HIGH:
                                    if self.verbose:
                                        print(f"  → Skipping non-high severity finding: {finding.file_path}:{finding.line_number}")
                                    continue
                                
                                findings.append(finding)
                            except Exception as e:
                                if self.verbose:
                                    print(f"  ⚠️ Error processing detect-secrets finding: {e}")
                except Exception as e:
                    print(f"⚠️ Error accessing files property: {e}")
                    print("Skipping detect-secrets results processing")
            
            print(f"  ✓ detect-secrets found {len(findings)} potential secrets")
            return findings
            
        except ImportError as e:
            print(f"⚠️ Warning: detect-secrets library not available: {e}")
            print("   Install with: pip install detect-secrets")
            return []
        except Exception as e:
            print(f"⚠️ Error using detect-secrets: {e}")
            if self.verbose:
                import traceback
                traceback.print_exc()
            return []
    
    def scan(self) -> List[Finding]:
        """
        Main scanning method that coordinates the entire scanning process.
        
        This method collects files to scan, runs the different scanning methods,
        and combines the results.
        
        Returns:
            List of all findings
        """
        print(f"🔍 Starting secret scan in: {os.path.abspath(self.directory)}")
        
        # Step 1: Collect files to scan
        files_to_scan = self._collect_files_to_scan()
        if not files_to_scan:
            print("No files to scan!")
            return []
        
        # Step 2: Scan files with custom patterns
        pattern_findings = []
        for file_idx, file_path in enumerate(files_to_scan):
            if self.verbose or file_idx % 100 == 0:
                print(f"  [{file_idx+1}/{len(files_to_scan)}] Scanning: {file_path}")
            
            file_findings = self.scan_file(file_path)
            pattern_findings.extend(file_findings)
        
        print(f"  ✓ Pattern scanner found {len(pattern_findings)} potential secrets")
        
        # Step 3: Run detect-secrets scanner if enabled
        detect_secrets_findings = []
        if self.use_detect_secrets:
            detect_secrets_findings = self._run_detect_secrets_scan(files_to_scan)
        
        # Step 4: Handle Git history if requested
        git_findings = []
        if self.check_git_history:
            git_scanner = GitHistoryScanner(self, self.directory)
            git_findings = git_scanner.scan_historical_files(self.deep_scan)
        
        # Step 5: Combine all findings and remove duplicates
        all_findings = pattern_findings + detect_secrets_findings + git_findings
        
        # Remove duplicates based on fingerprint
        unique_findings = {}
        for finding in all_findings:
            if finding.fingerprint not in unique_findings:
                unique_findings[finding.fingerprint] = finding
            else:
                # If duplicate, keep the higher severity one
                existing = unique_findings[finding.fingerprint]
                if (finding.severity == Severity.HIGH and existing.severity != Severity.HIGH) or \
                   (finding.severity == Severity.MEDIUM and existing.severity == Severity.LOW):
                    unique_findings[finding.fingerprint] = finding
        
        self.findings = list(unique_findings.values())
        print(f"✓ Scan complete: Found {len(self.findings)} unique findings")
        
        return self.findings
    
    def _is_git_repo(self) -> bool:
        """
        Check if the directory is a Git repository.
        
        Returns:
            True if the directory is a Git repository, False otherwise
        """
        return GitUtils.is_git_repository(self.directory)
    
    def _is_gitignored(self, file_path: str) -> bool:
        """
        Check if a file is ignored by Git.
        
        Args:
            file_path: Path to the file to check
            
        Returns:
            True if the file is gitignored, False otherwise
        """
        if not self._is_git_repo():
            return False
        
        return GitUtils.is_file_gitignored(file_path, self.directory)
    
    def print_report(self) -> bool:
        """
        Print a comprehensive report of all findings.
        
        This method groups findings by severity and risk type, and provides detailed
        information about each finding, including remediation guidance.
        
        Returns:
            True if any high severity findings were found, False otherwise
        """
        if not self.findings:
            print("\n✅ No secrets detected in the scanned files.")
            return False
        
        # Group findings by severity
        high_findings = [f for f in self.findings if f.severity == Severity.HIGH]
        medium_findings = [f for f in self.findings if f.severity == Severity.MEDIUM]
        low_findings = [f for f in self.findings if f.severity == Severity.LOW]
        
        # Group findings by risk type
        hardcoded_findings = [f for f in self.findings if f.risk_type == RiskType.HARDCODED_SECRET]
        log_exposure_findings = [f for f in self.findings if f.risk_type == RiskType.DATA_EXPOSURE_LOGS]
        response_exposure_findings = [f for f in self.findings if f.risk_type == RiskType.DATA_EXPOSURE_RESPONSE]
        config_findings = [f for f in self.findings if f.risk_type == RiskType.SENSITIVE_CONFIG]
        
        # Group findings by git status
        gitignored_findings = [f for f in self.findings if getattr(f, 'is_gitignored', False)]
        historical_findings = [f for f in self.findings if getattr(f, 'in_git_history', False)]
        
        # Get unique files with findings
        unique_files = set(f.file_path for f in self.findings)
        
        print("\n=== SCAN SUMMARY ===\n")
        print(f"🚨 Found {len(self.findings)} potential secrets in {len(unique_files)} files.")
        print(f"  🔴 HIGH SEVERITY: {len(high_findings)} findings")
        print(f"  🟠 MEDIUM SEVERITY: {len(medium_findings)} findings")
        print(f"  🟡 LOW SEVERITY: {len(low_findings)} findings")
        
        if gitignored_findings:
            print(f"\n  🔍 GITIGNORED FILES: {len(gitignored_findings)} findings in gitignored files")
        
        if historical_findings:
            print(f"\n  🔍 HISTORICAL FINDINGS: {len(historical_findings)} findings in files from Git history")
            tracked_historical = [f for f in historical_findings if getattr(f, 'is_still_tracked', False)]
            if tracked_historical:
                print(f"    ⚠️ CRITICAL: {len(tracked_historical)} findings in files that are STILL TRACKED (needs immediate attention)")
        
        print("\n=== FINDINGS BY RISK TYPE ===\n")
        print("  📊 FINDINGS BY RISK TYPE:")
        print(f"     - {len(hardcoded_findings)} hardcoded secrets")
        print(f"     - {len(log_exposure_findings)} data exposures in logs")
        print(f"     - {len(response_exposure_findings)} data exposures in responses")
        print(f"     - {len(config_findings)} sensitive configuration items")
        print()
        
        # First highlight critical files
        critical_files = {}
        for finding in self.findings:
            if finding.severity == Severity.HIGH:
                if finding.file_path not in critical_files:
                    critical_files[finding.file_path] = []
                critical_files[finding.file_path].append(finding)
        
        if critical_files:
            print("=== CRITICAL FILES ===\n")
            print("The following files have HIGH severity findings that need immediate attention:")
            for file_path, findings in critical_files.items():
                print(f"\n⚠️  {file_path}: {len(findings)} HIGH severity findings")
        
        # Historical files still tracked (highest risk)
        tracked_historical_files = {}
        for finding in historical_findings:
            if getattr(finding, 'is_still_tracked', False):
                if finding.file_path not in tracked_historical_files:
                    tracked_historical_files[finding.file_path] = []
                tracked_historical_files[finding.file_path].append(finding)
        
        if tracked_historical_files:
            print("\n=== CRITICAL: HISTORICAL FILES STILL TRACKED ===\n")
            print("The following files contain sensitive information, are in .gitignore,")
            print("but are STILL TRACKED by Git. These need immediate attention!")
            
            for file_path, findings in tracked_historical_files.items():
                high_count = sum(1 for f in findings if f.severity == Severity.HIGH)
                
                print(f"\n⚠️  CRITICAL: {file_path}")
                print(f"   {len(findings)} findings ({high_count} HIGH severity)")
                print("   This file needs to be removed from Git tracking!")
                
                # Show a sample finding
                if findings:
                    print("\n   Sample finding:")
                    finding = findings[0]
                    print(f"   Line {finding.line_number}: {finding.line_content}")
            
            print("\n   To remove these files from Git tracking (but keep them locally):")
            for file_path in tracked_historical_files:
                rel_path = os.path.relpath(file_path, self.directory)
                print(f"   git rm --cached \"{rel_path}\"")
            print("   git commit -m \"Remove sensitive files that should be gitignored\"")
            print("   git push")
            print()
        
        # Now show details for all findings
        print("=== DETAILED MATCHES ===\n")
        
        # Display detailed matches
        for finding in self.findings:
            # Prepare status indicators
            status_indicators = []
            if getattr(finding, 'is_gitignored', False):
                status_indicators.append("🔍 GITIGNORED")
            if getattr(finding, 'in_git_history', False):
                status_indicators.append("⚠️ IN GIT HISTORY")
            if getattr(finding, 'is_still_tracked', False):
                status_indicators.append("⚠️ STILL TRACKED")
            
            status_str = f" [{' - '.join(status_indicators)}]" if status_indicators else ""
            
            print(f"⚠️  {finding.severity.value} - {finding.risk_type.value} - MATCH FOUND in {finding.file_path} line {finding.line_number}{status_str}:")
            print(f"   FINGERPRINT: {finding.fingerprint}")
            print(f"   PATTERN: {finding.pattern}")
            
            if finding.description:
                print(f"   DESCRIPTION: {finding.description}")
            
            print("   CODE CONTEXT:")
            print("   " + "-" * 50)
            
            context_lines = self._get_context_lines(finding.file_path, finding.line_number)
            start_line = max(1, finding.line_number - 2)
            
            for i, line in enumerate(context_lines):
                line_num = start_line + i
                if line_num == finding.line_number:
                    print(f"   {line_num:3d} | {line.rstrip()}  <-- ⚠️ FINDING HERE")
                else:
                    print(f"   {line_num:3d} | {line.rstrip()}")
            
            print("   " + "-" * 50)
            print()
        
        # Generate allowlist file
        allowlist_file = "secrets_findings.yaml"
        self.allowlist_manager.generate_allowlist_from_findings(self.findings, allowlist_file)
        
        # Provide remediation guidance
        print("\n=== REMEDIATION GUIDANCE ===\n")
        print("🛠️  Next steps by risk type:")
        
        if historical_findings:
            print("\n=== HISTORICAL FILE CLEANUP GUIDANCE ===\n")
            print("Some sensitive files have been detected in Git history. To properly clean them:")
            
            print("\n1. For files still tracked by Git, first remove them from tracking:")
            if tracked_historical_files:
                for file_path in tracked_historical_files:
                    rel_path = os.path.relpath(file_path, self.directory)
                    print(f"   git rm --cached \"{rel_path}\"")
                print("   git commit -m \"Remove sensitive files that should be gitignored\"")
                print("   git push")
        
                print("\n2. To completely remove these files from Git history, use BFG Repo-Cleaner:")
                print("   a. Download BFG from: https://rtyley.github.io/bfg-repo-cleaner/")
                
                # Create file listing all historical files with findings
                history_files = set(f.file_path for f in historical_findings)
                with open("sensitive-git-history-files.txt", "w") as f:
                    for file_path in history_files:
                        rel_path = os.path.relpath(file_path, self.directory)
                        f.write(f"{rel_path}\n")
                
                print("   b. We've created a file with all sensitive files: sensitive-git-history-files.txt")
                print("   c. Follow these steps to clean the history:")
                print("      git clone --mirror git://your-repo.git repo.git")
                print("      java -jar bfg.jar --delete-files sensitive-git-history-files.txt repo.git")
                print("      cd repo.git")
                print("      git reflog expire --expire=now --all")
                print("      git gc --prune=now --aggressive")
                print("      git push")
                
                print("\n⚠️ WARNING: This will rewrite Git history. Coordinate with your team before proceeding.")
   
        if hardcoded_findings:
            print()
            print(f"   🔑 HARDCODED SECRETS ({len(hardcoded_findings)} findings):")
            print("     - Remove hardcoded secrets from code and use environment variables instead")
            print("     - Store secrets in a secure vault like AWS Secrets Manager, HashiCorp Vault, etc.")
            print("     - Use a .env file (not committed to version control) for local development")
            print("     - Consider any already-committed secrets compromised and rotate them immediately")
        
        if log_exposure_findings:
            print()
            print(f"   📝 DATA EXPOSURE IN LOGS ({len(log_exposure_findings)} findings):")
            print("     - Never log sensitive values like passwords, tokens, or keys")
            print("     - Use redaction patterns like console.log('token:', '***REDACTED***')")
            print("     - Create helper functions that automatically redact sensitive fields")
            print("     - Implement proper debug levels to control what gets logged")
        
        if response_exposure_findings:
            print()
            print(f"   🌐 DATA EXPOSURE IN RESPONSES ({len(response_exposure_findings)} findings):")
            print("     - Never return sensitive values in API responses")
            print("     - Create data sanitization functions that strip sensitive fields before sending")
            print("     - Use response schemas or serializers that explicitly define what gets returned")
            print("     - Add unit tests to verify sensitive data isn't leaked in responses")
        
        if config_findings:
            print()
            print(f"   ⚙️ SENSITIVE CONFIGURATION ({len(config_findings)} findings):")
            print("     - Move sensitive values from configuration files to environment variables")
            print("     - Use .env.example files with placeholder values as templates")
            print("     - In CI/CD environments, use secure environment variable storage")
            print("     - For infrastructure-as-code, use secure variable handling mechanisms")
        
        print()
        print("🔁 CI/CD Integration:")
        print(f"   A file '{allowlist_file}' has been created with all findings.")
        print("   To suppress known/acceptable findings:")
        print(f"   1. Review the findings and update {self.allowlist_file} with acceptable ones")
        print("   2. Run with --high-only flag to only fail on high severity findings")
        print("   Example: python secrets_scanner.py --high-only")
        
        print()
        print("🔄 Next Steps:")
        print("   1. Review all HIGH and MEDIUM severity findings immediately")
        print("   2. For each finding, follow the remediation guidance to fix the issue")
        print("   3. If a finding is a false positive, add it to the allowlist file")
        print("   4. For gitignored files with secrets that were previously committed, rotate those secrets")
        print("   5. Consider implementing pre-commit hooks to prevent new secrets from being committed")
        print("   6. Run the scanner regularly as part of your CI/CD pipeline using the --high-only flag")
        print()
        
        if high_findings:
            print("⚠️ HIGH SEVERITY FINDINGS REQUIRE IMMEDIATE ATTENTION")
            print("   Secrets exposed in your codebase pose a significant security risk and should be")
            print("   addressed as soon as possible. Consider rotating any exposed credentials.")
       
        # Return True if there are any high severity findings
        return len(high_findings) > 0


def main():
    """
    Main entry point for the secrets scanner.
    
    Parses command line arguments and runs the scanner with the specified options.
    """
    parser = argparse.ArgumentParser(
        description="Enhanced Python Secrets Scanner - Detects hardcoded credentials and sensitive data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python secrets_scanner.py                                # Run in loose mode
  python secrets_scanner.py --mode strict                  # Run in strict mode
  python secrets_scanner.py --verbose                      # Run in loose mode with verbose output
  python secrets_scanner.py --high-only                    # Run in loose mode, only fail on high severity
  python secrets_scanner.py --allowlist-file custom.yaml   # Use custom allowlist file
  python secrets_scanner.py --check-git-history            # Check Git history
  python secrets_scanner.py --deep-scan                    # Perform deep scan
        """
    )
    parser.add_argument("--mode", choices=["loose", "strict"], default="loose",
                        help="Scanning mode: 'loose' (fewer false positives) or 'strict' (more thorough)")
    parser.add_argument("--verbose", action="store_true",
                        help="Show more detailed output")
    parser.add_argument("--high-only", action="store_true",
                        help="Only fail on HIGH severity findings (good for CI/CD)")
    parser.add_argument("--allowlist-file", default=".secrets-allowlist.yaml",
                        help="Path to allowlist file")
    parser.add_argument("--directory", default=".",
                        help="Directory to scan")
    parser.add_argument("--scan-gitignored", action="store_true",
                        help="Also scan files excluded by .gitignore")
    parser.add_argument("--check-git-history", action="store_true",
                        help="Check for secrets in gitignored files that were previously committed")
    parser.add_argument("--deep-scan", action="store_true",
                        help="Perform a deep scan (slower but more thorough)")
    parser.add_argument("--skip-detect-secrets", action="store_true",
                        help="Skip using detect-secrets library")
    parser.add_argument("--pattern-file", default=None,
                        help="Path to pattern definitions file")
    parser.add_argument("--generate-allowlist", action="store_true",
                        help="Generate an allowlist file from findings")
    
    args = parser.parse_args()
    
    # Print header
    print("=" * 60)
    print("📦 Enhanced Python Secrets Scanner")
    print("=" * 60)
    
    scanner = SecretsScanner(
        mode=args.mode,
        verbose=args.verbose,
        high_only=args.high_only,
        allowlist_file=args.allowlist_file,
        directory=args.directory,
        scan_gitignored=args.scan_gitignored,
        check_git_history=args.check_git_history,
        deep_scan=args.deep_scan,
        use_detect_secrets=not args.skip_detect_secrets,
        pattern_file=args.pattern_file
    )
    
    # Run the scan
    findings = scanner.scan()
    
    # Print report
    high_findings_exist = scanner.print_report()
    
    # Generate allowlist if requested
    if args.generate_allowlist and findings:
        allowlist_file = "generated_allowlist.yaml"
        scanner.allowlist_manager.generate_allowlist_from_findings(findings, allowlist_file)
        print(f"\n✓ Generated allowlist file: {allowlist_file}")
        print("  Review and move approved items to your main allowlist file")
    
    # Exit with the appropriate status code
    if args.high_only:
        if high_findings_exist:
            print("❌ CI/CD Check Failed: High severity findings detected")
            sys.exit(1)
        else:
            print("✅ CI/CD Check Passed: No high severity findings detected")
            sys.exit(0)
    elif findings:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()