# ---+ Extensions
# ---++ CmisPlugin
# This is the configuration used by the <b>CmisPlugin</b>.

# **BOOLEAN**
# switch on to enable debug output
$Foswiki::cfg{CmisPlugin}{Debug} = 0;

# **STRING**
# This is the ID in the {Connections} hash below that is used
# as the default connection when no other connection is specified
# explicitly. If left empty, the first connection specified in {Connections}
# will be used as a default
$Foswiki::cfg{CmisPlugin}{DefaultConnection} = '';

# **PERL**
# List of connections to different CMIS repositories. Each entry is 
# identified by a unique key ("alfresco" in the default example) and
# holds at least four entries: 
# (1) url - the address of the cmis endpoint,
# (2) user - account to be used by default accessing the repository and
# (3) password - the default user's password.
# (4) repositoryId - the name of the repository; leave undefined to use the default repository.
# (5) webdavUrl- the access point from where a document can be edited in a native application using webdav
# (6) cacheExpires - the maximum time an entry is kept fresh in the cache
# (7) overrideCacheControl - if enabled, any cache control of the CMIS backend will be ignored in favor of
# (8) loginUrl - REST api to aquire a transaction ticket 
# (9) logoutUrl - REST api to delete a transaction ticket during logout
# more performance but with the disadvantage of missing some updates due to caching more aggressively at
# the client side.
$Foswiki::cfg{CmisPlugin}{Connections} = {
  alfresco => {
    url => "http://localhost:8080/alfresco/service/cmis",
    user => "...",
    password => "...",
    repositoryId => undef,
    webdavUrl => 'webdav://$host:8080/alfresco/webdav/$path/$name'
    cacheExpires => '10 minutes',
    overrideCacheControl => 0,
    loginUrl => "http://localhost:8080/alfresco/service/api/login?u={username}&pw={password}",
    logoutUrl => "http://localhost:8080/alfresco/service/api/login/ticket/{ticket}",
  },
  alfresco_demo => {
    url => "http://cmis.alfresco.com/service/cmis",
    user => "admin",
    password => "admin",
    repositoryId => undef,
    webdavUrl => 'webdav://cmis.alfresco.com/webdav/$path/$name'
    cacheExpires => '10 minutes',
    overrideCacheControl => 1,
    loginUrl => "http://localhost:8080/alfresco/service/api/login?u={username}&pw={password}",
    logoutUrl => "http://localhost:8080/alfresco/service/api/login/ticket/{ticket}",
  }
};

# **REGEX**
# Specify a regular expression matching file extensions to be editable in a
# native application via webdav.
$Foswiki::cfg{CmisPlugin}{WebDAVFilter} = qr/((xlt|xls|csv|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp|rtf|txt/;

1;
