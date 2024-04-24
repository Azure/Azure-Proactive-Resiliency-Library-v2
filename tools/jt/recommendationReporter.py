import os
import glob
from termcolor import colored, cprint
# import yaml

# *** Functions ***
# **Find all recommendations.yaml files in the azure-resources directory and child folders**

def get_number_of_folders(path_to_recommendations='../../azure-resources'):
    root_folders = glob.glob('*', root_dir=path_to_recommendations, recursive=False)
    number_of_root_folders = len(root_folders)-1

    number_of_child_folders = 0
    for dir in root_folders:
        child_folders = glob.glob(f'{dir}/*', root_dir=path_to_recommendations, recursive=False)
        number_of_child_folders += len(child_folders)

    return number_of_root_folders, number_of_child_folders

# Get all recommendations.yml from the /azure-resources directory and child folders
def get_recommendations(path_to_recommendations='../../azure-resources'):
    recommendations = glob.glob('./**/recommendations.yaml', root_dir=path_to_recommendations, recursive=True)
    return recommendations

# Get all azure-resources top level folders from recommendations return from get_recommendations and print the folder name
def get_resource_dirs_and_info():
    resource_folders = []
    list_of_azure_rps = []
    list_of_azure_rps_and_types = []
    for recommendation in get_recommendations():
        path_parts = os.path.split(recommendation)
        azure_rp = os.path.split(path_parts[0])[0]
        if azure_rp.startswith('.\\'):
          azure_rp = azure_rp[2:]
        azure_rp_type = os.path.basename(os.path.dirname(recommendation))
        list_of_azure_rps.append(azure_rp)
        list_of_azure_rps_and_types.append(azure_rp + '/' + azure_rp_type)
        resource_folders.append(azure_rp + '/' + azure_rp_type)

        # Deduplicate list_of_azure_rps and list_of_azure_rps_and_types
        list_of_azure_rps = sorted(list(dict.fromkeys(list_of_azure_rps)), key=str.lower)
        list_of_azure_rps_and_types = sorted(list(dict.fromkeys(list_of_azure_rps_and_types)), key=str.lower)
    return [resource_folders, list_of_azure_rps, list_of_azure_rps_and_types]

# *** Variables ***
out_get_number_of_folders_root = get_number_of_folders()[0]
out_get_number_of_folders_child = get_number_of_folders()[1]
out_get_recommendations = get_recommendations()
out_get_resource_dirs_and_info = get_resource_dirs_and_info()
out_azure_rps = out_get_resource_dirs_and_info[1]
out_azure_rps_and_types = out_get_resource_dirs_and_info[2]

# *** Main ***
print(colored(f'*** Recommendation Reporter ***', 'black', 'on_light_yellow'), end='\n\n')

print(colored(f'Found {len(out_get_recommendations)} recommendations.yaml files in the azure-resources directory out of a total number of {out_get_number_of_folders_child} Azure resource directories...', 'light_cyan'), end='\n')

print(colored(f'Percentage of recommendations.yaml files found compared to total amount of Azure resource directories (excluding `kql` dirs): ', 'light_cyan'), end='')
percentage = round((len(out_get_recommendations)/out_get_number_of_folders_child)*100, 2)
if percentage < 50:
  color = 'red'
elif percentage < 100:
  color = 'light_yellow'
else:
  color = 'light_green'
print(colored(f'{percentage}%', color, attrs=['bold']), end='\n\n')

# print(f'Recommendation\'s Path: {out_get_recommendations}', end='\n\n')

print(colored(f'Found recommendations for the following {len(out_azure_rps)} Azure RP Namespaces:', 'light_cyan'))
index = 0
for azure_rp in out_azure_rps:
    index += 1
    print(colored(f'{index}: Microsoft.{azure_rp}', 'light_yellow'))

index = 0
print(colored(f'\nFound recommendations for the following {len(out_azure_rps_and_types)} Azure Resource Types:', 'light_cyan'))
for azure_rp_w_type in out_azure_rps_and_types:
    index += 1
    print(colored(f'{index}: Microsoft.{azure_rp_w_type}', 'light_yellow'))



