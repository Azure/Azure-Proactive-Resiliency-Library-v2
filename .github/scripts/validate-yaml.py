import os
import argparse
import glob
import yaml
from termcolor import colored, cprint
import pandas as pd
import xlsxwriter
import re

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

def valid_uuid(uuid):
    regex = re.compile('^[a-f0-9]{8}-?[a-f0-9]{4}-?4[a-f0-9]{3}-?[89ab][a-f0-9]{3}-?[a-f0-9]{12}\Z', re.I)
    match = regex.match(uuid)
    return bool(match)
