$csv = [System.Collections.Generic.List[string]]::new()
$csv.Add('Question ID (machine readable),Response ID (machine readable),Response value,Answer requirement,Human-friendly question label')

function Q($id) {
    if ($id -match '[",]') { '"' + ($id -replace '"', '""') + '"' } else { $id }
}

function AddRow($qid, $rid, $val, $req, $label) {
    $v = if ($null -eq $val -or $val -eq '') { '' } else { $val.ToString().ToLower() }
    $csv.Add("$(Q $qid),$(Q $rid),$v,$(Q $req),$(Q $label)")
}

# Global questions
AddRow 'PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA' '' 'TRUE' 'REQUIRED' 'Does your app collect or share any of the required user data types?'
AddRow 'PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT' '' 'TRUE' 'MAYBE_REQUIRED' 'Is all of the user data collected by your app encrypted in transit?'
AddRow 'PSL_DATA_COLLECTION_USER_REQUEST_DELETE' '' 'FALSE' 'MAYBE_REQUIRED' 'Do you provide a way for users to request that their data is deleted?'

$purposeIds = @(
    'PSL_APP_FUNCTIONALITY',
    'PSL_ANALYTICS',
    'PSL_DEVELOPER_COMMUNICATIONS',
    'PSL_FRAUD_PREVENTION_SECURITY',
    'PSL_PERSONALIZATION',
    'PSL_ACCOUNT_MANAGEMENT',
    'PSL_ADVERTISING'
)

$purposeNames = @(
    'App functionality',
    'Analytics',
    'Developer communications',
    'Fraud prevention, security and compliance',
    'Personalisation',
    'Account management',
    'Advertising or marketing'
)

# Category, DataTypeId, DataTypeName, Collected, Shared, Ephemeral, Optional, CollectionPurposes, SharePurposes
$types = @(
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_NAME','Name','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_EMAIL','Email address','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_USER_ACCOUNT','Personal identifiers','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_ADDRESS','Address','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_PHONE','Phone number','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_RACE_ETHNICITY','Race and ethnicity','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_POLITICAL_RELIGIOUS','Political or religious beliefs','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_SEXUAL_ORIENTATION_GENDER_IDENTITY','Sexual orientation','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_PERSONAL','Personal info','PSL_OTHER_PERSONAL','Other personal info','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_FINANCIAL','Financial info','PSL_PURCHASE_HISTORY','Purchase history','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;ACCOUNT_MANAGEMENT;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_FINANCIAL','Financial info','PSL_CREDIT_SCORE','Credit info','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_FINANCIAL','Financial info','PSL_CREDIT_DEBIT_BANK_ACCOUNT_NUMBER','Credit card, debit card or bank account number','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_FINANCIAL','Financial info','PSL_OTHER','Other financial info','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_LOCATION','Location','PSL_APPROX_LOCATION','Approximate location','TRUE','TRUE','FALSE','TRUE','APP_FUNCTIONALITY;PERSONALIZATION;ADVERTISING','ADVERTISING'),
    @('PSL_DATA_TYPES_LOCATION','Location','PSL_PRECISE_LOCATION','Precise location','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY',''),
    @('PSL_DATA_TYPES_SEARCH_AND_BROWSING','Web browsing','PSL_WEB_BROWSING_HISTORY','Web browsing history','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_EMAIL_AND_TEXT','Messages','PSL_EMAILS','Emails','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_EMAIL_AND_TEXT','Messages','PSL_SMS_CALL_LOG','SMS or MMS messages','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_EMAIL_AND_TEXT','Messages','PSL_OTHER_MESSAGES','Other in-app messages','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY',''),
    @('PSL_DATA_TYPES_PHOTOS_AND_VIDEOS','Photos and videos','PSL_PHOTOS','Photos','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_PHOTOS_AND_VIDEOS','Photos and videos','PSL_VIDEOS','Videos','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_AUDIO','Audio files','PSL_AUDIO','Voice or sound recordings','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY',''),
    @('PSL_DATA_TYPES_AUDIO','Audio files','PSL_MUSIC','Music files','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY',''),
    @('PSL_DATA_TYPES_AUDIO','Audio files','PSL_OTHER_AUDIO','Other audio files','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_HEALTH_AND_FITNESS','Health and fitness','PSL_HEALTH','Health information','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_HEALTH_AND_FITNESS','Health and fitness','PSL_FITNESS','Fitness information','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_CONTACTS','Contacts','PSL_CONTACTS','Contacts','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_CALENDAR','Calendar','PSL_CALENDAR','Calendar events','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_APP_PERFORMANCE','App info and performance','PSL_CRASH_LOGS','Crash logs','TRUE','FALSE','FALSE','FALSE','ANALYTICS;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_APP_PERFORMANCE','App info and performance','PSL_PERFORMANCE_DIAGNOSTICS','Diagnostics','TRUE','FALSE','FALSE','FALSE','ANALYTICS;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_APP_PERFORMANCE','App info and performance','PSL_OTHER_PERFORMANCE','Other app performance data','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_FILES_AND_DOCS','Files and docs','PSL_FILES_AND_DOCS','Files and docs','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY',''),
    @('PSL_DATA_TYPES_APP_ACTIVITY','App activity','PSL_USER_INTERACTION','Page views and taps in app','TRUE','TRUE','FALSE','FALSE','APP_FUNCTIONALITY;ANALYTICS;ADVERTISING','ADVERTISING'),
    @('PSL_DATA_TYPES_APP_ACTIVITY','App activity','PSL_IN_APP_SEARCH_HISTORY','In-app search history','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;ANALYTICS;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_APP_ACTIVITY','App activity','PSL_APPS_ON_DEVICE','Installed apps','FALSE','FALSE','FALSE','FALSE','',''),
    @('PSL_DATA_TYPES_APP_ACTIVITY','App activity','PSL_USER_GENERATED_CONTENT','Other user-generated content','TRUE','FALSE','FALSE','TRUE','APP_FUNCTIONALITY;PERSONALIZATION',''),
    @('PSL_DATA_TYPES_APP_ACTIVITY','App activity','PSL_OTHER_APP_ACTIVITY','Other actions','TRUE','FALSE','FALSE','FALSE','APP_FUNCTIONALITY;ANALYTICS;FRAUD_PREVENTION_SECURITY',''),
    @('PSL_DATA_TYPES_IDENTIFIERS','Device or other identifiers','PSL_DEVICE_ID','Device or other identifiers','TRUE','TRUE','FALSE','FALSE','APP_FUNCTIONALITY;ANALYTICS;FRAUD_PREVENTION_SECURITY;ADVERTISING','ADVERTISING')
)

foreach ($t in $types) {
    $catId = $t[0]
    $catName = $t[1]
    $dtId = $t[2]
    $dtName = $t[3]
    $collected = $t[4]
    $shared = $t[5]
    $ephemeral = $t[6]
    $optional = $t[7]
    $collPurposes = $t[8]
    $sharePurposes = $t[9]

    # Data type row
    AddRow $catId $dtId $collected 'MULTIPLE_CHOICE' "$catName/$dtName"

    # Collection/sharing
    if ($collected -eq 'TRUE') {
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_COLLECTION_AND_SHARING" 'PSL_DATA_USAGE_ONLY_COLLECTED' 'TRUE' 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Is this data collected, shared or both?/Collected"
        if ($shared -eq 'TRUE') {
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_COLLECTION_AND_SHARING" 'PSL_DATA_USAGE_ONLY_SHARED' 'TRUE' 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Is this data collected, shared or both?/Shared"
        } else {
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_COLLECTION_AND_SHARING" 'PSL_DATA_USAGE_ONLY_SHARED' '' 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Is this data collected, shared or both?/Shared"
        }
    } else {
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_COLLECTION_AND_SHARING" 'PSL_DATA_USAGE_ONLY_COLLECTED' '' 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Is this data collected, shared or both?/Collected"
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_COLLECTION_AND_SHARING" 'PSL_DATA_USAGE_ONLY_SHARED' '' 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Is this data collected, shared or both?/Shared"
    }

    # Ephemeral
    $ephemeralValue = if ($collected -eq 'TRUE') { $ephemeral } else { '' }
    AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:PSL_DATA_USAGE_EPHEMERAL" '' $ephemeralValue 'MAYBE_REQUIRED' "Data usage and handling ($dtName)/Is this data processed ephemerally?"

    # User control
    if ($collected -eq 'TRUE') {
        if ($optional -eq 'TRUE') {
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL' 'TRUE' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Users can choose whether this data is collected"
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED' '' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Data collection is required (users can not turn off this data collection)"
        } else {
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL' '' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Users can choose whether this data is collected"
            AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED' 'TRUE' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Data collection is required (users can not turn off this data collection)"
        }
    } else {
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL' '' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Users can choose whether this data is collected"
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_USER_CONTROL" 'PSL_DATA_USAGE_USER_CONTROL_REQUIRED' '' 'SINGLE_CHOICE' "Data usage and handling ($dtName)/Is this data required for your app, or can users choose whether it is collected?/Data collection is required (users can not turn off this data collection)"
    }

    # Collection purposes
    for ($i = 0; $i -lt $purposeIds.Count; $i++) {
        $pId2 = $purposeIds[$i]
        $pname = $purposeNames[$i]
        $short = $pId2 -replace '^PSL_'
        $selected = if ($collPurposes -and $collPurposes.Split(';') -contains $short) { 'TRUE' } else { '' }
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_COLLECTION_PURPOSE" $pId2 $selected 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Why is this user data collected? Select all that apply./$pname"
    }

    # Sharing purposes
    for ($i = 0; $i -lt $purposeIds.Count; $i++) {
        $pId2 = $purposeIds[$i]
        $pname = $purposeNames[$i]
        $short = $pId2 -replace '^PSL_'
        $selected = if ($sharePurposes -and $sharePurposes.Split(';') -contains $short) { 'TRUE' } else { '' }
        AddRow "PSL_DATA_USAGE_RESPONSES:${dtId}:DATA_USAGE_SHARING_PURPOSE" $pId2 $selected 'MULTIPLE_CHOICE' "Data usage and handling ($dtName)/Why is this user data shared? Select all that apply./$pname"
    }
}

$csv | Out-File 'data_safety.csv' -Encoding utf8
"Generated data_safety.csv with $($csv.Count) rows."
