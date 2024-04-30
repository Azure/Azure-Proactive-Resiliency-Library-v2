import os
import argparse
import glob
import yaml
from termcolor import colored, cprint
import pandas as pd
import xlsxwriter

# Required packages
required_packages = {
    "termcolor": "termcolor",
    "PyYAML": "yaml",
    "pandas": "pandas",
    "XlsxWriter": "xlsxwriter"
}

# Check for missing packages
missing_packages = []
for package, module in required_packages.items():
    try:
        __import__(module)
    except ImportError:
        missing_packages.append(package)

if missing_packages:
    print("Missing required packages. Please install them by running:")
    print(f"pip install {' '.join(missing_packages)}")
    exit(1)

# Functions
# Validate YAML fields
def validate_yaml_fields(recommendation):
    required_fields = [
        'description', 'aprlGuid', 'recommendationControl', 'recommendationImpact',
        'longDescription', 'potentialBenefits', 'pgVerified', 'publishedToLearn',
        'publishedToAdvisor', 'automationAvailable', 'learnMoreLink'
    ]

    for field in required_fields:
        if field not in recommendation:
            return False, f"Field '{field}' is missing in a recommendation."

    if not isinstance(recommendation['learnMoreLink'], list):
        return False, "Learn More Link should be a list."

    return True, ""
