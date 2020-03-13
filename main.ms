<!
	strict;
	requiredExtensions: MSXodus;
>

include('procs.ms');
include('model.ms');
include('github.ms');

// Argument parsing
@db = file_resolve($1 ||| prompt_line("Database location> "));
@project = $2 ||| prompt_line("Project name> ");
@configFile = $3 ||| '~/.youtrack-to-github/config.json';

// Special project names
if(@project == "$pricing") {
	xodus_transaction_entity(@db, "teamsysstore", closure() {
		_validateDB();
		@users = length(xodus_get_all('User'));
		@total = 0;
		// $4 - 1-100, $3 - 101-200, $2 - 201-300, $1 - 301+
		if(@users >= 300) {
			@total += (@users - 300) * 1;
			@users = 300;
		}
		if(@users >= 200) {
			@total += (@users - 200) * 2;
			@users = 200;
		}
		if(@users >= 100) {
			@total += (@users - 100) * 3;
			@users = 100;
		}
		@total += @users * 4;

		msg("A paid license for this installation costs $" . @total);
		exit();
	}, true);
}

if(@project == "$list") {
	xodus_transaction_entity(@db, "teamsysstore", closure() {
		_validateDB();
		msg('Listing projects:');
		@projects = _getProjects();
		msg(@projects);
		exit();
	}, true);
}

if(@project == "$customFields") {
	xodus_transaction_entity(@db, "teamsysstore", closure() {
		@customFields = array();
		foreach(@issue in xodus_get_all('Issue')) {
			foreach(@link in @issue['links']) {
				// msg(@link);
				if(reg_match("__CUSTOM_FIELD__.*", @link)) {
					if(!array_contains(@customFields, @link)) {
						@customFields[] = @link;
					}
				}
			}
		}
		msg('Custom fields are: ' . @customFields);
		exit();
	});
}

if(@project == '$tables') {
	xodus_transaction_entity(@db, "teamsysstore", closure() {
		msg(array_sort(xodus_get_types()));
		exit();
	}, true);
}

if(@project == "$clearModel") {
	@issueName = prompt_line('Issue Name ("everything" for the whole model): ');
	if(@issueName == 'everything') {
		if('y' != prompt_char('Are you sure you want to clear the entire data model? ')) {
			die('Aborting.');
		}
		_clearModel();
	}
	_clearIssueFromModel(@issueName);
	exit();
}
// Normal processing
msg(color('GOLD') . "Using '@db' as the database location");
msg(color('GOLD') . "Using '@project' as the project");
msg(color('GOLD') . "Reading config from @configFile");

if(file_size(@configFile) == 0) {
	// Create the template and exit
	x_write(@configFile, json_encode(array(
		"interactive": true,
		"token": "",
		"owner": "",
		"repo": "",
		"applicationName":"",
		"doUpload": false,
		"testLimit": 0,
		"stateField": "__CUSTOM_FIELD__State_2",
		"closedStates": array("Can't Reproduce","Duplicate","Fixed","Incomplete","Obsolete","Won't fix"),
		"stateTable": "IssueState",
		"skippedStates": array(),
	)));
	die("Template config file written out to '@configFile'. Please fill it in and run again.");
}

@config = json_decode(read(@configFile));

if(trim(@config['token']) == "") {
	die(color('RED') . "Missing token, cannot continue. Please check the @configFile file");
}

if(trim(@config['applicationName']) == "") {
	die(color('RED') . "Missing applicationName, cannot continue. Please check the @configFile file");
}

export('config-token', secure_string(@config['token']));
@config['token'] = "";
export('config-applicationName', @config['applicationName']);
export('config-do-upload', @config['doUpload']);
export('config-test-limit', @config['testLimit']);
export('config-state-table', @config['stateTable']);
export('config-state-field', @config['stateField']);
export('config-closed-states', @config['closedStates']);
export('config-skipped-states', @config['skippedStates']);
export('config-interactive', @config['interactive']);

if(@project == "$states") {
	xodus_transaction_entity(@db, "teamsysstore", closure() {
		// msg(array_sort(xodus_get_types()));
		@states = array();
		foreach(@state in xodus_get_all(import('config-state-table'))) {
			@states[] = @state['properties']['name'];
		}
		msg(json_encode(array_sort(@states)));
		exit();
	});
}

@owner = null;
while(!@owner) {
	@owner = @config['owner'] ||| prompt_line("Repo Owner> ");
}

@repo = null;
while(!@repo) {
	@repo = @config['repo'] ||| prompt_line("Repo Name> ");
}

msg(color('GOLD') . "Using @owner as the owner");
msg(color('GOLD') . "Using @repo as the repo");
export('config-owner', @owner);
export('config-repo', @repo);

xodus_transaction_entity(@db, "teamsysstore", closure() {
	_validateDB();
	if(!array_contains(_getProjects(), @project)) {
		msg(color('RED') . "Couldn't find the project @project");
		exit();
	}
}, true);

if(import('config-do-upload')) {
	msg("Validating github access...");
	_verifyGithubAccess();
	msg("success");
}

xodus_transaction_entity(@db, "teamsysstore", closure() {
	msg(color('GOLD') . "Processing database...");
	@issues = _processDatabase(@project);
	if(import('config-do-upload')) {
		if(import('config-interactive')) {
			if(!equals_ic('y', prompt_char('Continue with upload? [y/n]: '))) {
				die('Cancelling run.');
			}
		}
		// msg('UPLOAD TIME BBY');
		_uploadIssues(@issues);
	}
}, true);

exit(0);