
proc _apiCall(@subpath, @params = null, @method = "GET") {
	@cookiejar = import('api-call-cookiejar');
	if(@cookiejar == null) {
		@cookiejar = array();
	}
	
	@response = array();
	@headers = array(
		'User-Agent': import('config-applicationName'),
		'Accept': array(
			'application/vnd.github.v3+json', 
			'application/vnd.github.squirrel-girl-preview',
			'application/vnd.github.golden-comet-preview',
		),
		'Host': 'api.github.com',
		'Authorization': 'token '.array_implode(decrypt_secure_string(import('config-token')), '')
	);
	@url = 'http://localhost:9000/' . @subpath;
	@url = 'https://api.github.com/' . @subpath;
	msg(color('GREEN') . @method . ' ' . @url . if(@params && @params instanceof array, '?' . map_implode(@params, '=', '&')));
	if(@method == 'PATCH') {
		@method = 'POST';
		@headers['X-HTTP-Method-Override'] = 'PATCH';
	}

	http_request(@url, array(
		blocking: true,
		method: @method,
		params: @params,
		headers: @headers,
		useDefaultHeaders: false,
		cookiejar: @cookiejar,
		success: closure(@ret) {
			@response[] = @ret;
		},
		error: closure(@ex) {
			msg(@ex);
			exit(1);
		}
	));
	export('api-call-cookiejar', @cookiejar);
	
	@response = @response[0];
	@statusColor = color('GREEN');
	if(@response['responseCode'] > 299) {
		@statusColor = color('RED');
	}
	msg(@statusColor . @response['responseCode'] . ' ' . @response['responseText']);
	try {
		@response['quotaRemaining'] = @response['headers']['X-RateLimit-Remaining'][0];
		msg(color('GOLD').'Quota: ' . @response['headers']['X-RateLimit-Remaining'][0]
			. '/' . @response['headers']['X-RateLimit-Limit'][0]
			. ' (resets ' . simple_date('HH:mm:ss z', @response['headers']['X-RateLimit-Reset'][0] * 1000)
			. ')');
	} catch(IndexOverflowException @ex) {
		// Ignore this, something went really wrong.
	}

	// msg(@response['headers']);
	if(string_contains(to_lower(@response['headers']['Content-Type'][0]),'application/json')) {
		@response['body'] = json_decode(@response['body']);
	}

	if(@response['responseCode'] > 299) {
		msg(@response);
		msg("Exiting due to non 200 response code");
		exit(1);
	}
	return(@response);
}

proc _verifyGithubAccess() {
	_apiCall('rate_limit');
}