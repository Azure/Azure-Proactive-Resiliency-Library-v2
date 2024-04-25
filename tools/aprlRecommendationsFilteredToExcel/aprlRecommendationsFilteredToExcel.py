required_packages = {
    "termcolor": "termcolor",
    "PyYAML": "yaml",
    "pandas": "pandas",
    "XlsxWriter": "xlsxwriter"
}

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

import os
import argparse
import glob
from termcolor import colored, cprint
import yaml
import json
import pandas as pd
import xlsxwriter

# *** Arguments ***
parser = argparse.ArgumentParser(description='Get all APRL recommendations and filter to only high impact and PG verified recommendations, by default; can be changed via inputs. Write the filtered recommendations to an Excel file.')
parser.add_argument('--path_to_recommendations', type=str, default='../../azure-resources', help='Path to the azure-resources directory in the APRL repo that you have cloned locally.')
parser.add_argument('--filter_impact_level', type=str, default='High', choices=['High', 'Medium', 'Low', 'All'] , help='Filter level for impact (e.g., High, Medium, Low, All)')
parser.add_argument('--allow_non_pg_verified', action='store_true', help='Only PG verified recommendations are exported by default. Use this flag to include non-PG verified recommendations also.')
parser.add_argument('--output_file_name', type=str, default='aprlFilteredRecommendations.xlsx', help='Name of the output Excel file. This will be output to the directory where you are running this script from.')
args = parser.parse_args()

# *** Functions ***
# **Find all recommendations.yaml files in the azure-resources directory and child folders**
def get_number_of_folders(path_to_recommendations=args.path_to_recommendations):
    root_folders = glob.glob('*', root_dir=path_to_recommendations, recursive=False)
    number_of_root_folders = len(root_folders)-1

    number_of_child_folders = 0
    for dir in root_folders:
        child_folders = glob.glob(f'{dir}/*', root_dir=path_to_recommendations, recursive=False)
        number_of_child_folders += len(child_folders)

    return number_of_root_folders, number_of_child_folders

# Get all recommendations.yml from the /azure-resources directory and child folders
def get_recommendations(path_to_recommendations=args.path_to_recommendations):
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

# Get all recommendations data from yaml files and filter out to only the high impact and pg verified recommendations
def get_recommendations_data_and_filter(recommendations=get_recommendations(path_to_recommendations=args.path_to_recommendations), filter_impact_level=args.filter_impact_level, allow_non_pg_verified=args.allow_non_pg_verified):
  azure_resources_dir = os.path.normpath(args.path_to_recommendations)

  aprl_filtered_recommendations = {}
  aprl_base_url = 'https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/azure-resources/'

  for recommendation in recommendations:
      recommendation_path = os.path.join(azure_resources_dir, recommendation)  # Constructs an absolute path to the recommendation file
      recommendation_path = os.path.normpath(recommendation_path)  # Normalize the path to ensure it's correctly formatted
      if "\\" in recommendation_path:
        recommendation_path_parts = recommendation_path.split('\\')
      else:
        recommendation_path_parts = recommendation_path.split('/')
      aprl_resource_complete_url = aprl_base_url + recommendation_path_parts[-3] + '/' + recommendation_path_parts[-2]  # Construct the complete URL to the APRL resource
      try:
          with open(recommendation_path, 'r', encoding='utf-8-sig') as file:
              # Load the file as a list of dictionaries
              recommendations_data = yaml.safe_load(file)
              # print(colored(f'\n{recommendation_path} has {len(recommendations_data)} recommendations in total', 'light_green'), end='\n')
              # Check if recommendations_data is a list and iterate over it
              if isinstance(recommendations_data, list):
                  for rec in recommendations_data:
                      if allow_non_pg_verified == False:
                        if filter_impact_level == 'All':
                          if rec.get('recommendationImpact') == 'High' or rec.get('recommendationImpact') == 'Medium' or rec.get('recommendationImpact') == 'Low':
                            if rec.get('pgVerified') == True:
                                aprl_filtered_recommendations.update({rec["aprlGuid"]:\
                                {
                                  "recommendationResourceType": rec.get("recommendationResourceType", "defaultType"),
                                  "aprlGuid": rec.get("aprlGuid", "defaultGuid"),
                                  "description": rec.get("description", "No description available"),
                                  "recommendationControl": rec.get("recommendationControl", "defaultControl"),
                                  "recommendationImpact": rec.get("recommendationImpact", "defaultImpact"),
                                  "recommendationMetadataState": rec.get("recommendationMetadataState", "defaultState"),
                                  "pgVerified": rec.get("pgVerified", False),
                                  "publishedToLearn": rec.get("publishedToLearn", False),
                                  "publishedToAdvisor": rec.get("publishedToAdvisor", False),
                                  "automationAvailable": rec.get("automationAvailable", False),
                                  "aprlUrlForResource": aprl_resource_complete_url,  # Assuming this is defined elsewhere and always available
                                  "recommendationFilePath": recommendation_path  # Assuming this is defined elsewhere and always available
                                }})
                        elif filter_impact_level != 'All':
                          if rec.get('recommendationImpact') == filter_impact_level and rec.get('pgVerified') == True:
                              aprl_filtered_recommendations.update({rec["aprlGuid"]:\
                              {
                                  "recommendationResourceType": rec.get("recommendationResourceType", "defaultType"),
                                  "aprlGuid": rec.get("aprlGuid", "defaultGuid"),
                                  "description": rec.get("description", "No description available"),
                                  "recommendationControl": rec.get("recommendationControl", "defaultControl"),
                                  "recommendationImpact": rec.get("recommendationImpact", "defaultImpact"),
                                  "recommendationMetadataState": rec.get("recommendationMetadataState", "defaultState"),
                                  "pgVerified": rec.get("pgVerified", False),
                                  "publishedToLearn": rec.get("publishedToLearn", False),
                                  "publishedToAdvisor": rec.get("publishedToAdvisor", False),
                                  "automationAvailable": rec.get("automationAvailable", False),
                                  "aprlUrlForResource": aprl_resource_complete_url,  # Assuming this is defined elsewhere and always available
                                  "recommendationFilePath": recommendation_path  # Assuming this is defined elsewhere and always available
                                }})
                      if allow_non_pg_verified == True:
                          if filter_impact_level == 'All':
                            if rec.get('recommendationImpact') == 'High' or rec.get('recommendationImpact') == 'Medium' or rec.get('recommendationImpact') == 'Low':
                                aprl_filtered_recommendations.update({rec["aprlGuid"]:\
                                {
                                  "recommendationResourceType": rec.get("recommendationResourceType", "defaultType"),
                                  "aprlGuid": rec.get("aprlGuid", "defaultGuid"),
                                  "description": rec.get("description", "No description available"),
                                  "recommendationControl": rec.get("recommendationControl", "defaultControl"),
                                  "recommendationImpact": rec.get("recommendationImpact", "defaultImpact"),
                                  "recommendationMetadataState": rec.get("recommendationMetadataState", "defaultState"),
                                  "pgVerified": rec.get("pgVerified", False),
                                  "publishedToLearn": rec.get("publishedToLearn", False),
                                  "publishedToAdvisor": rec.get("publishedToAdvisor", False),
                                  "automationAvailable": rec.get("automationAvailable", False),
                                  "aprlUrlForResource": aprl_resource_complete_url,  # Assuming this is defined elsewhere and always available
                                  "recommendationFilePath": recommendation_path  # Assuming this is defined elsewhere and always available
                                }})
                          elif filter_impact_level != 'All':
                            if rec.get('recommendationImpact') == filter_impact_level:
                              aprl_filtered_recommendations.update({rec["aprlGuid"]:\
                              {
                                  "recommendationResourceType": rec.get("recommendationResourceType", "defaultType"),
                                  "aprlGuid": rec.get("aprlGuid", "defaultGuid"),
                                  "description": rec.get("description", "No description available"),
                                  "recommendationControl": rec.get("recommendationControl", "defaultControl"),
                                  "recommendationImpact": rec.get("recommendationImpact", "defaultImpact"),
                                  "recommendationMetadataState": rec.get("recommendationMetadataState", "defaultState"),
                                  "pgVerified": rec.get("pgVerified", False),
                                  "publishedToLearn": rec.get("publishedToLearn", False),
                                  "publishedToAdvisor": rec.get("publishedToAdvisor", False),
                                  "automationAvailable": rec.get("automationAvailable", False),
                                  "aprlUrlForResource": aprl_resource_complete_url,  # Assuming this is defined elsewhere and always available
                                  "recommendationFilePath": recommendation_path  # Assuming this is defined elsewhere and always available
                                }})
              else:
                  print(f"Unexpected data structure in {recommendation_path}: {type(recommendations_data)}")
      except FileNotFoundError:
          print(f"File not found: {recommendation_path}")
  return aprl_filtered_recommendations

# Write the high impact and pg verified recommendations from APRL to an Excel file
def write_to_excel(aprl_filtered_recommendations=get_recommendations_data_and_filter(filter_impact_level=args.filter_impact_level, allow_non_pg_verified=args.allow_non_pg_verified), output_file_name=args.output_file_name):
  try:
      df = pd.DataFrame(data=aprl_filtered_recommendations)
      df = df.T  # Transpose the DataFrame
      writer = pd.ExcelWriter(output_file_name, engine='xlsxwriter')
      df.to_excel(writer, sheet_name='APRL Filtered Recommendations', index=False)

      workbook = writer.book
      worksheet = writer.sheets['APRL Filtered Recommendations']
      (max_row, max_col) = df.shape

      # Create a center alignment format
      center_format = workbook.add_format({'align': 'center'})

      # Apply center alignment format to all columns except the first two
      worksheet.set_column(2, max_col - 1, None, center_format)  # Start from the third column

      # Define the table with column settings
      column_settings = [{"header": column} for column in df.columns]
      worksheet.add_table(0, 0, max_row, max_col - 1, {"columns": column_settings})

      # Autofit the columns
      worksheet.autofit()

      # Close the Pandas Excel writer and output the Excel file
      writer.close()
      print(colored(f'XLSX file created successfully: {os.path.abspath(output_file_name)}', 'light_green'), end='\n')
  except PermissionError as e:
      print(colored(f"Failed to save the file {output_file_name}: {e}. Please ensure the file is not open in another program and you have write permissions to the directory and file.", 'red'), end='\n')
  except Exception as e:
      print(colored(f"An unexpected error occurred: {e}", 'red'), end='\n')

# *** Variables ***
out_get_number_of_folders_root = get_number_of_folders()[0]
out_get_number_of_folders_child = get_number_of_folders()[1]
out_get_recommendations = get_recommendations()
out_get_resource_dirs_and_info = get_resource_dirs_and_info()
out_azure_rps = out_get_resource_dirs_and_info[1]
out_azure_rps_and_types = out_get_resource_dirs_and_info[2]

# *** Main ***
print(colored(f'*** APRL Recommendation Filtering Tool ***', 'black', 'on_light_yellow'), end='\n\n')

print(colored(f'---> Arguments provided (or default values) to be used for script run...', 'black', 'on_light_grey'), end='\n')
print(colored(f'     --path_to_recommendations: {args.path_to_recommendations}', 'black', 'on_light_grey'), end='\n')
print(colored(f'     --filter_impact_level: {args.filter_impact_level}', 'black', 'on_light_grey'), end='\n')
print(colored(f'     --allow_non_pg_verified: {args.allow_non_pg_verified}', 'black', 'on_light_grey'), end='\n')
print(colored(f'     --Output file name: {args.output_file_name}', 'black', 'on_light_grey'), end='\n\n')

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

print(colored(f'---> Found recommendations for the following {len(out_azure_rps)} Azure Resource Provider Namespaces:', 'light_cyan'))
index = 0
for azure_rp in out_azure_rps:
  index += 1
  print(colored(f'     {index}: Microsoft.{azure_rp}', 'light_cyan'))

index = 0
print(colored(f'\n---> Found recommendations for the following {len(out_azure_rps_and_types)} Azure Resource Types:', 'light_cyan'))
for azure_rp_w_type in out_azure_rps_and_types:
  index += 1
  print(colored(f'     {index}: Microsoft.{azure_rp_w_type}', 'light_cyan'))
print()

print(colored(f'---> Filtering APRL recommendations to Recommendation Impact Level: {args.filter_impact_level}, Allow Non-PG Verified Recommendations?: {args.allow_non_pg_verified}...', 'black', 'on_light_grey'), end='\n\n')
write_to_excel()
