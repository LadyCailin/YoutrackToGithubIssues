

proc _clearModel() {
    x_write('model.json', '', 'OVERWRITE');
}

proc _addIssue(@issue) {
    try {
        @array = json_decode(read('model.json'));
    } catch(Exception @e) {
        @array = array();
    }
    @array[] = @issue['issueName'];
    x_write('model.json', json_encode(@array), 'OVERWRITE');
}

proc _modelHasIssue(@issue) {
    try {
        @array = json_decode(read('model.json'));
    } catch(Exception @e) {
        return(false);
    }
    return(array_contains(@array, @issue['issueName']));
}

proc _clearIssueFromModel(@issueName) {
    try {
        @array = json_decode(read('model.json'));
    } catch(Exception @e) {
        return(false);
    }
    array_remove_values(@array, @issueName);
    x_write('model.json', json_encode(@array), 'OVERWRITE');
}