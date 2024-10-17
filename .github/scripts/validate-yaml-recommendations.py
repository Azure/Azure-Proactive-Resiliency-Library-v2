required_packages = {
    "yamale": "yamale",
}

missing_packages = []
for package, module in required_packages.items():
    try:
        __import__(module)
    except ImportError:
        missing_packages.append(package)

if missing_packages:
    import subprocess
    for package_name in missing_packages:
        subprocess.check_call(['pip', 'install', required_packages[package_name]])

    # Verify installation
    missing_packages = []
    for package, module in required_packages.items():
        try:
            __import__(module)
        except ImportError as e:
            print(f"Failed to import {module}: {e}")
            missing_packages.append(package)

    if missing_packages:
        print("Failed to install required packages:")
        print(missing_packages)
        exit(1)

import os
import yamale

# Directories containing YAML files to validate
directories = {
    './azure-resources': './.github/scripts/schemas/azure-resources-and-waf-schema.yaml',
    './azure-specialized-workloads': './.github/scripts/schemas/azure-specialized-workloads-schema.yaml',
    './azure-waf': './.github/scripts/schemas/azure-resources-and-waf-schema.yaml'
}

# Function to validate a YAML file against the schema
def validate_yaml_file(file_path, schema_path):
    # Make a schema object
    schema_obj = yamale.make_schema(schema_path)
    # Create a Data object
    data = yamale.make_data(file_path)
    try:
        # Validate data against the schema
        yamale.validate(schema_obj, data)
        print(f'{file_path}: Valid YAML')
    except ValueError as e:
        print(f'{file_path}: {e}')
        raise RuntimeError(f"YAML validation failed for {file_path}.")

# Initialize error counter
error_count = 0

# Loop through directories
print("Validating YAML files against schemas...")
for directory, schema_path in directories.items():
    if not os.path.exists(directory):
        print(f"Directory {directory} does not exist.")
        continue  # Skip validation for this directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.yaml'):
                file_path = os.path.join(root, file)
                try:
                    validate_yaml_file(file_path, schema_path)
                except RuntimeError as e:
                    print(e)
                    error_count += 1

# Check if any errors were encountered
if error_count == 1:
    raise RuntimeError(f"{error_count} YAML file failed validation.")
elif error_count > 1:
    raise RuntimeError(f"{error_count} YAML files failed validation.")
else:
    print("All YAML files are valid.")
