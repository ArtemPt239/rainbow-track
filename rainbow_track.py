#!/usr/bin/env python3
import json
import os
import sys

API_URL = 'https://api.track.toggl.com/api/v9'
CONFIG_DIR_PATH = os.path.dirname(os.path.realpath(__file__))
number_of_runs_till_sync = 5
number_of_runs_till_projects_sync = 60*60

CONNECTION_STATUS_OK = 'ok'


CONFIG_FILENAME = 'config.json'
try:
    with open(f"{CONFIG_DIR_PATH}/{CONFIG_FILENAME}") as config_file:
        config_json = json.load(config_file)
        API_TOKEN = str(config_json["token"])
        WORKPLACE_ID = int(config_json["workplace_id"])
except FileNotFoundError:
    print("Config file not found")
    print(f"Make sure that {CONFIG_FILENAME} exists")
    sys.exit(1)
except json.decoder.JSONDecodeError:
    print("Could not parse the config file")
    sys.exit(2)
except KeyError as e:
    print(f"Could not find key {e} in the config file")
    sys.exit(3)
except Exception as e:
    print("Unexpected error:", e)
    sys.exit(4)


def get_persistent_variable(file_name: str, default_value=None):
    try:
        with open(f"{CONFIG_DIR_PATH}/var/{file_name}") as variable_file:
            return variable_file.read()
    except FileNotFoundError:
        return default_value


def save_persistent_variable(value, file_name: str):
    with open(f"{CONFIG_DIR_PATH}/var/{file_name}", 'w') as variable_file:
        variable_file.write(str(value))


def build_output():
    """ Prints output, used by Argos to construct the extension"""

    def paint_text(text: str, hex_color: str) -> str:
        # Extra empty span is required for color to work properly in older GNOME version
        # See https://github.com/p-e-w/argos/issues/112#issuecomment-611539550
        return f'<span> </span><span foreground="{hex_color}">{text}</span>'

    from datetime import datetime

    projects_json_string = get_persistent_variable('projects')
    if projects_json_string is None:
        sync_projects()
        projects_json_string = get_persistent_variable('projects')
    projects = json.loads(projects_json_string)

    connection_status = ':red_circle:' if get_persistent_variable('connection_status') != CONNECTION_STATUS_OK else ''

    current_time_entry = json.loads(get_persistent_variable('current_time_entry'))
    if current_time_entry is not None:
        description = current_time_entry['description']
        description_string = f"({description})" if not (description is None or description == "") else ""

        project = projects[str(current_time_entry['pid'])]
        project_color = project['hex_color']
        project_name = project['name']

        duration_in_seconds = int(datetime.now().timestamp() + current_time_entry['duration'])
        duration_string = f'{duration_in_seconds // 3600 :d}:{(duration_in_seconds % 3600) // 60 :02d}:{duration_in_seconds % 60 :02d}'

        print(f"{connection_status}{paint_text(f'{project_name} {duration_string}', project_color)} {description_string}")

        print("---")

        current_datetime = datetime.now().astimezone().replace(microsecond=0)
        print((f"{paint_text('Stop timer', '#ff0000')} | "
               f"bash='curl -v -u {API_TOKEN}:api_token"
               f" -H \"Content-Type: application/json\""
               f" -d \"{{\\\"id\\\":{current_time_entry['id']},\\\"duration\\\":{int(current_time_entry['duration'] + current_datetime.timestamp())},\\\"stop\\\":\\\"{current_datetime.isoformat()}\\\",\\\"wid\\\":{WORKPLACE_ID}}}\""
               f" -X PUT {API_URL}/time_entries/{current_time_entry['id']} ; python3 {CONFIG_DIR_PATH}/sync_current_timer.py'"
               f" terminal=false refresh=true"))
    else:
        print(f"{connection_status} Timer stopped")

    print("---")

    for pid in projects.keys():
        current_datetime = datetime.now().astimezone().replace(microsecond=0)
        print((f"{paint_text(projects[pid]['name'], projects[pid]['hex_color'])} | "
               f"bash='curl -v -u {API_TOKEN}:api_token"
               f" -H \"Content-Type: application/json\""
               f" -d \"{{\\\"pid\\\":{pid},\\\"created_with\\\":\\\"rainbow track\\\",\\\"start\\\":\\\"{current_datetime.isoformat()}\\\",\\\"stop\\\":null,\\\"duration\\\":{int(-current_datetime.timestamp())},\\\"wid\\\":{WORKPLACE_ID}}}\""
               f" -X POST {API_URL}/time_entries ; python3 {CONFIG_DIR_PATH}/sync_current_timer.py'"
               f" terminal=false refresh=true"))

    print("---")
    #
    # print("Settings")

    print((f"Sync projects manually | "
           f"bash='python3 {CONFIG_DIR_PATH}/sync_projects.py'"
           f" terminal=false refresh=true"))



def make_api_request(resource_location: str):
    import requests
    from base64 import b64encode

    authorization_header = 'Basic %s' % b64encode(f"{API_TOKEN}:api_token".encode('ascii')).decode("ascii")
    headers = {"Content-Type": "application/json", 'Authorization': authorization_header}
    data = requests.get(f'{API_URL}/{resource_location}', headers=headers)
    return data


def check_if_connection_is_ok(function):
    import requests
    def wrapper(*args, **kwargs):
        try:
            result = function(*args, **kwargs)
            save_persistent_variable(CONNECTION_STATUS_OK, 'connection_status')
            return result
        except requests.exceptions.ConnectionError as e:
            save_persistent_variable(e, 'connection_status')
    return wrapper


@check_if_connection_is_ok
def sync_current_timer():
    """ Syncs current timer with the toggl api"""
    save_persistent_variable(json.dumps(make_api_request('me/time_entries/current').json()), 'current_time_entry')


@check_if_connection_is_ok
def sync_projects():
    """ Syncs list of projects with the toggl api"""
    projects = {project['id']: {'name': project['name'], 'hex_color': project['color']}
                for project in sorted(make_api_request('me/projects').json(), key=lambda x: x['name'])}
    save_persistent_variable(json.dumps(projects, indent=4), 'projects')


def main():
    run_number = int(get_persistent_variable('run_number', default_value=0))

    if run_number >= number_of_runs_till_projects_sync:
        sync_projects()
        run_number = 0

    if run_number >= number_of_runs_till_sync:
        sync_current_timer()
        run_number = 0

    save_persistent_variable(run_number + 1, 'run_number')
    build_output()


if __name__ == '__main__':
    main()
