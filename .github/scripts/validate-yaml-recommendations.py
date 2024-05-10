required_packages = {
    "yamale": "yamale"
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

# Import Yamale and make a schema object:
import yamale
schema = yamale.make_schema('.\\recommendation-schema.yaml')

# Create a Data object
data = yamale.make_data('.\\recommendations.yaml')

# Validate data against the schema. Throws a ValueError if data is invalid.
yamale.validate(schema, data)
