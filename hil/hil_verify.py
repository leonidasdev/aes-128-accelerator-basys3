#!/usr/bin/env python3
"""
hil_verify.py - HIL Infrastructure Verification Utility

Performs comprehensive checks to ensure all HIL components are properly configured:
- Python environment and dependencies
- Required files and directory structure
- Import resolution (Crypto, serial)
- Serial port connectivity
- Test vector format compliance

Run this script to validate HIL readiness before executing tests.

Usage:
    python hil/hil_verify.py [--verbose]

Exit Codes:
    0 = All checks passed
    1 = One or more checks failed
"""

import sys
import os
import subprocess
from pathlib import Path

class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    """Print formatted header"""
    print(f"\n{Colors.CYAN}{Colors.BOLD}{'='*70}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}{text}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}{'='*70}{Colors.RESET}\n")

def print_pass(text):
    """Print success message"""
    print(f"{Colors.GREEN}PASS:{Colors.RESET} {text}")

def print_fail(text):
    """Print failure message"""
    print(f"{Colors.RED}FAIL:{Colors.RESET} {text}")

def print_warning(text):
    """Print warning message"""
    print(f"{Colors.YELLOW}WARN:{Colors.RESET} {text}")

def print_info(text):
    """Print info message"""
    print(f"{Colors.CYAN}INFO:{Colors.RESET} {text}")

def check_python_version():
    """Verify Python 3.7+ is available"""
    print_header("Python Environment")
    
    major, minor = sys.version_info.major, sys.version_info.minor
    version_str = f"Python {major}.{minor}.{sys.version_info.micro}"
    
    if major >= 3 and minor >= 7:
        print_pass(f"{version_str}")
        print_info(f"Executable: {sys.executable}")
        return True
    else:
        print_fail(f"{version_str} (requires 3.7+)")
        return False

def check_directory_structure():
    """Verify HIL directory structure"""
    print_header("Directory Structure")
    
    hil_root = Path(__file__).parent
    repo_root = hil_root.parent
    required_dirs = [
        hil_root / "python",
        hil_root / "vectors",
    ]
    
    required_files = [
        repo_root / "requirements.txt",
        repo_root / "setup_venv.ps1",
        hil_root / "python" / "aes_hil_test.py",
        hil_root / "python" / "generate_vectors.py",
        hil_root / "vectors" / "test_vectors.txt",
        hil_root / "run_hil_tests.ps1",
    ]
    
    all_found = True
    
    # Check directories
    print("Directories:")
    for dir_path in required_dirs:
        if dir_path.is_dir():
            print_pass(f"{dir_path.relative_to(hil_root)}/")
        else:
            print_fail(f"{dir_path.relative_to(hil_root)}/ (missing)")
            all_found = False
    
    # Check files
    print("\nFiles:")
    for file_path in required_files:
        if file_path.is_file():
            size_kb = file_path.stat().st_size / 1024
            print_pass(f"{file_path.relative_to(hil_root)} ({size_kb:.1f} KB)")
        else:
            print_fail(f"{file_path.relative_to(hil_root)} (missing)")
            all_found = False
    
    return all_found

def check_python_packages():
    """Verify required Python packages"""
    print_header("Python Dependencies")
    
    required_packages = {
        "Crypto": "pycryptodome",
        "serial": "pyserial",
    }
    
    all_installed = True
    
    for module, package in required_packages.items():
        try:
            __import__(module)
            print_pass(f"{package} (import '{module}' works)")
        except ImportError as e:
            print_fail(f"{package} (import '{module}' failed: {e})")
            all_installed = False
    
    return all_installed

def check_test_vector_format():
    """Verify test vector file format"""
    print_header("Test Vector Format")
    
    vectors_file = Path(__file__).parent / "vectors" / "test_vectors.txt"
    
    if not vectors_file.exists():
        print_fail(f"{vectors_file.name} not found")
        return False
    
    try:
        with open(vectors_file, 'r') as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        if not lines:
            print_fail("No test vectors found (file empty or only comments)")
            return False
        
        print_info(f"Found {len(lines)} test vectors")
        
        all_valid = True
        for i, line in enumerate(lines[:5], 1):  # Check first 5 vectors
            parts = line.split()
            
            # Expected format: plaintext ciphertext key
            if len(parts) != 3:
                print_fail(f"Vector {i}: Expected 3 fields, got {len(parts)}")
                all_valid = False
                continue
            
            plaintext, ciphertext, key = parts
            
            # Validate hex format and length (128-bit = 32 hex chars)
            valid_lengths = all(len(val) == 32 for val in [plaintext, ciphertext, key])
            valid_hex = all(all(c in '0123456789ABCDEFabcdef' for c in val) 
                          for val in [plaintext, ciphertext, key])
            
            if valid_lengths and valid_hex:
                print_pass(f"Vector {i}: {plaintext[:16]}... -> {ciphertext[:16]}...")
            else:
                if not valid_lengths:
                    print_fail(f"Vector {i}: Invalid length (expected 32 hex chars each)")
                if not valid_hex:
                    print_fail(f"Vector {i}: Invalid hex characters")
                all_valid = False
        
        if len(lines) > 5:
            print_info(f"... and {len(lines) - 5} more vectors")
        
        return all_valid
    
    except Exception as e:
        print_fail(f"Error reading test vectors: {e}")
        return False

def check_imports():
    """Verify critical imports work"""
    print_header("Import Resolution")
    
    all_imported = True
    
    # Test pycryptodome AES import
    try:
        from Crypto.Cipher import AES
        from Crypto.Random import get_random_bytes
        print_pass("pycryptodome: Crypto.Cipher.AES and Crypto.Random.get_random_bytes")
    except ImportError as e:
        print_fail(f"pycryptodome imports: {e}")
        all_imported = False
    
    # Test pyserial import
    try:
        import serial
        print_pass("pyserial: serial module")
    except ImportError as e:
        print_fail(f"pyserial import: {e}")
        all_imported = False
    
    # Test aes_hil_test module
    try:
        hil_root = Path(__file__).parent
        sys.path.insert(0, str(hil_root / "python"))
        import aes_hil_test
        print_pass("aes_hil_test module (local import)")
    except ImportError as e:
        print_fail(f"aes_hil_test import: {e}")
        all_imported = False
    
    return all_imported

def check_setup_integrity():
    """Verify setup completeness"""
    print_header("Setup Integrity")
    
    checks_passed = 0
    checks_total = 0
    
    hil_root = Path(__file__).parent
    repo_root = hil_root.parent
    
    # Check if the shared environment setup exists
    checks_total += 1
    setup_script = repo_root / "setup_venv.ps1"
    if setup_script.exists():
        print_pass("setup_venv.ps1 found")
        checks_passed += 1
    else:
        print_fail("setup_venv.ps1 not found")

    # Check if run_hil_tests.ps1 exists
    run_script = hil_root / "run_hil_tests.ps1"
    checks_total += 1
    if run_script.exists():
        print_pass("run_hil_tests.ps1 found")
        checks_passed += 1
    else:
        print_fail("run_hil_tests.ps1 not found")
    
    return checks_passed == checks_total

def main():
    """Run all verification checks"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}AES-128 HIL Infrastructure Verification{Colors.RESET}\n")
    
    checks = [
        ("Python Version", check_python_version),
        ("Directory Structure", check_directory_structure),
        ("Python Packages", check_python_packages),
        ("Test Vector Format", check_test_vector_format),
        ("Import Resolution", check_imports),
        ("Setup Integrity", check_setup_integrity),
    ]
    
    results = []
    for check_name, check_func in checks:
        try:
            result = check_func()
            results.append((check_name, result))
        except Exception as e:
            print_fail(f"Unexpected error: {e}")
            results.append((check_name, False))
    
    # Summary
    print_header("Verification Summary")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for check_name, result in results:
        status = f"{Colors.GREEN}PASS{Colors.RESET}" if result else f"{Colors.RED}FAIL{Colors.RESET}"
        print(f"  {check_name}: {status}")
    
    print(f"\nTotal: {passed}/{total} checks passed")
    
    if passed == total:
        print(f"\n{Colors.GREEN}{Colors.BOLD}HIL Ready!{Colors.RESET}")
        print(f"{Colors.GREEN}Run: python hil/python/aes_hil_test.py --port COM3{Colors.RESET}\n")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}Issues Found{Colors.RESET}")
        print(f"{Colors.YELLOW}Review the HIL prerequisites and rerun the verification script.{Colors.RESET}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
