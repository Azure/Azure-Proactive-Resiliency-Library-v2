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

# Validate UUID
def valid_uuid(uuid):
    regex = re.compile('^[a-f0-9]{8}-?[a-f0-9]{4}-?4[a-f0-9]{3}-?[89ab][a-f0-9]{3}-?[a-f0-9]{12}\Z', re.I)
    match = regex.match(uuid)
    return bool(match)

# Validate Description
def validate_description(description):
    if len(description) > 100:
        return False, "Description should be less than 100 characters."
    return True, ""

# Validation Long Description
def validate_long_description(longDescription):
    if len(longDescription) > 3000:
        return False, "Long Description should be less than 300 characters."
    return True, ""

# Validate aprlGuid
def validate_aprlGuid(aprlGuid):
    if not valid_uuid(aprlGuid):
        return False, "aprlGuid is not a valid UUID."
    return True, ""

# Validate recommendationControl
def validate_recommendationControl(recommendationControl):
    if recommendationControl not in ['High Availability', 'Business Continuity', 'Disaster Recovery', 'Scalability', 'Monitoring and Alerting', 'Service Upgrade and Retirement', 'Other Best Practices', 'Personalized', 'Governance']:
        return False, "Recommendation Control should be one of the following: High Availability, Business Continuity, Disaster Recovery, Scalability, Monitoring and Alerting, Service Upgrade and Retirement, Other Best Practices, Personalized, Governance."
    return True, ""

# Validate recommendationImpact
def validate_recommendationImpact(recommendationImpact):
    if recommendationImpact not in ['High', 'Medium', 'Low']:
        return False, "Recommendation Impact should be one of the following: High, Medium, Low."
    return True, ""

#Validate potentialBenefits
def validate_potentialBenefits(potentialBenefits):
    if len(potentialBenefits) > 60:
        return False, "Potential Benefits should be less than 60 characters."
    return True, ""


