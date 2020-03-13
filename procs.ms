<! strict; >

proc _validateDB() {
	@types = xodus_get_types();
	if(length(@types) == 0) {
		msg(color('RED') . 'Something went wrong, and the database appears to be empty.');
		exit(1);
	}
}

proc _getProjects() {
	@projects = xodus_get_all('Project');
	@projects = array_map(@projects, closure(@item) { return(@item['properties']['name']); });
	return(@projects);
}

/**
 * This must be called in a transaction
 */
proc _processDatabase(@project) {
	@issueRet = array();
	@issues = xodus_get_all('Issue');

	@count = 0;
	@uploadSegments = 0;
	foreach(@issue in @issues) {
		@date = integer(@issue['properties']['created']);
		@issueProject = "";
		@summary = "";
		@reporter = "";
		@description = "";
		@issueName = "";
		@comments = array();
		@closed = false;
		@issueState = "";

		if(array_contains(@issue['links'], import('config-state-field'))) {
			@currentState = xodus_entity_from_id(xodus_read_links(@issue, import('config-state-field'))[0])['properties']['name'];
			@issueState = @currentState;
			// msg(@currentState . import('config-closed-states'));
			if(array_contains_ic(import('config-closed-states'), @currentState)) {
				@closed = true;
			}
		}

		if(array_contains(@issue['links'], 'draftOwner')) {
			// It appears that these are drafts that aren't actually published, and can be skipped.
			continue();
		}


		if(array_contains(@issue['links'], 'project')) {
			@issueInProject = xodus_entity_from_id(xodus_read_links(@issue, 'project')[0])['properties'];
			@issueProject = @issueInProject['name'];
			@issueName = @issueInProject['shortName'] . '-' . @issue['properties']['numberInProject'];
			// msg("Issue @issueName has state @issueState");
			// msg("Issue in project @issueInProject");
			if(@issueInProject['name'] != @project) {
				continue();
			}
		} else {
			continue();
		}

		if(array_contains_ic(import('config-skipped-states'), @issueState)) {
			// msg('Skipping ' . @issueName . ' due to it being in the ' . @issueState . ' state');
			continue();
		}
		// Summary
		if(array_index_exists(@issue['properties'], 'summary')) {
			@summary = @issue['properties']['summary'];
		}

		// Reporter
		if(array_contains(@issue['links'], 'reporter')) {
			@reporter = xodus_entity_from_id(xodus_read_links(@issue, 'reporter')[0])['properties']['login'];
		}

		// Description
		if(array_contains(@issue['blobs'], 'description')) {
			@description = _fullTextReplacer(string_from_bytes(xodus_read_blob(@issue, 'description')));
		}

		if(array_contains(@issue['links'], 'comments')) {
			foreach(@comment in xodus_read_links(@issue, 'comments')) {
				@comment = xodus_entity_from_id(@comment);
				@comments[] = _commentToArray(@comment);
			}
		}

		@issueObj = array(
			'date': @date,
			'reporter': @reporter,
			'summary': @summary,
			'description': @description,
			'comments': @comments,
			'project': @issueProject,
			'issueId': @issue['id'],
			'issueName': @issueName,
			'closed': @closed,
			'issueState': @issueState,
		);

		@issueRet[] = @issueObj;
		// msg(@issueRet);
		@testLimit = integer(import('config-test-limit'));
		@uploadSegments++;
		if(@testLimit != 0 && ++@count >= @testLimit) {
			break();
		}
	}

	if(!import('config-do-upload')) {
		array_sort(@issueRet, closure(@left, @right) {
			// msg(@left);
			if(@left['date'] > @right['date']) {
				return(true);
			} else if(@right['date'] > @left['date']) {
				return(false);
			} else {
				return(null);
			}
		});
		foreach(@issueObj in @issueRet) {
			_outputIssue(@issueObj);
		}
	}

	msg('Upload Segments: ' . @uploadSegments . " (Each segment takes a bit more than one second to upload.)");	

	return(@issueRet);	
}

proc _outputIssue(@issue) {
	msg(color('CYAN') . "== " . @issue['issueName'] . " ========================================");
	msg(color('GOLD') . "Reporter: " . @issue['reporter'] . " on " . simple_date('yyyy-MM-dd HH:mm:ss z', @issue['date']));
	// msg("'".@issue['issueState']."'");
	msg(if(@issue['closed'], color('GREEN') . 'Closed', color('RED') . 'Open'));
	msg(color('GREEN') . "Summary: " . @issue['summary']);
	msg(color('GREEN') . "Description");
	msg(@issue['description']);
	foreach(@key: @comment in @issue['comments']) {
		// msg("Comment @key:");
		msg(color('GREEN') . "===============");
		msg(color('GOLD') . "Author: " . @comment['author'] . " on " . simple_date('yyyy-MM-dd HH:mm:ss z', @comment['created']));
		msg(@comment['text']);
	}
}

proc _commentToArray(@comment) {
	// msg(@comment);
	@commentAuthor = xodus_entity_from_id(xodus_read_links(@comment, 'author')[0])['properties']['login'];
	@created = @comment['properties']['created'];
	@text = _fullTextReplacer(string_from_bytes(xodus_read_blob(@comment, 'text')));
	@ret = array(
		'author': @commentAuthor,
		'created': @created,
		'text': @text,
	);
	// msg(@ret);
	return(@ret);
}

proc _fullTextReplacer(@text) {
	// There's some weird characters at the beginning, but I'm not sure what they are supposed to mean.
	@text = @text[2..];
	@text = reg_replace('\\{code:? ?lang=(.*?)\\}', '```$1\n', @text);
	@text = reg_replace('\\{code\\}', '```\n', @text);
	@text = reg_replace('(?s)\\{quote\\}(.*?)\\{quote\\}', '```\n$1\n```', @text);
	@text = reg_replace('(?s)\\{monospace\\}(.*?)\\{monospace\\}', '```\n$1\n```', @text);
	return(@text);
}

proc _uploadIssues(@issues) {
	@owner = import('config-owner');
	@repo = import('config-repo');
	@in = import('config-interactive');
	@count = 0;
	try {
		x_write('control.txt', '');
	} catch (IOException @e) {
		//
	}
	foreach(@issue in @issues) {
		msg(color('CYAN') . "== " . @issue['issueName'] . " ========================================");
		msg("Count at: @count");
		if(_modelHasIssue(@issue)) {
			msg(@issue['issueName'] . ' already uploaded, skipping');
			continue();
		}
		msg(color('GOLD') . 'Uploading ' . @issue['issueName']);
		// msg(@issue);

		@commentsArray = array();
		foreach(@comment in @issue['comments']) {
			msg('Generating comment by ' . @comment['author']);
			@commentBody = 'Comment by ' . @comment['author']
				. '\n\n'
				. @comment['text'];
			@commentsArray[] = array(
				'created_at': simple_date('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', @comment['created'], 'UTC'),
				'body': @commentBody
			);
		}

		@issueBody = @issue['issueName'] 
			. ' - Reported by ' . @issue['reporter']
			. '\n\n'
			. @issue['description'];
		@issueArray = array(
			'issue': array(
				'title': @issue['summary'],
				'body': @issueBody,
				'created_at': simple_date('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', @issue['date'], 'UTC')
			),
			'comments': @commentsArray
		);
		if(@issue['closed']) {
			msg(color('GREEN') . 'Closing issue');
			@issueArray['issue']['closed'] = true;
			@issueArray['issue']['closed_at'] = simple_date('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', time(), 'UTC');
		}
		// msg(json_encode(@issueArray));
		@issueResponse = _apiCall("repos/@owner/@repo/import/issues", json_encode(@issueArray), 'POST');
		@githubIssueId = @issueResponse['body']['id'];
		msg("Uploaded issue @githubIssueId");
		_addIssue(@issue);

		// Loop Control
		sleep(1);
		@count++;
		@control = read('control.txt');
		if(reg_match('(?i).*stop.*', @control)) {
			msg('Got stop signal, stopping now.')
			break();
		}
		if(@in) {
			@res = prompt_char(color('RED') . 'Continue? [y/n/a]: ');
			print_out(color('RESET'));
			if(equals_ic('a', @res)) {
				@in = false;
			} else if(!equals_ic('y', @res)) {
				break();
			}
		}
		
	}
	msg("Done, uploaded @count issue(s).");
}