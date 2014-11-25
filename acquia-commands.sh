[Tasks]
task-list;GET;List a site's tasks;/sites/:site/tasks
task-info;GET;Get a task record;/sites/:site/tasks/:task

[Domains]
domain-list;GET;List an environment's domains;/sites/:site/envs/:env/domains
domain-delete;DELETE;Delete a domain;/sites/:site/envs/:env/domains/:domain
domain-purge;DELTE;Purge the Varnish cache for a domain;/sites/:site/envs/:env/domains/:domain/cache

[Servers]
server-list;GET;List a site environment's servers;/sites/:site/envs/:env/servers

[SSH keys]
sshkey-list;GET;List a site's SSH keys;/sites/:site/sshkeys
sshkey-info;GET;Get an SSH key;/sites/:site/sshkeys/:sshkeyid

[Database]
database-list;GET;List a site's databases;/sites/:site/dbs
database-backup;POST;Create a database instance backup;/sites/:site/envs/:env/dbs/:db/backups

[Workflow]
database-copy;POST;Copy a database from one site environment to another;/sites/:site/dbs/:db/db-copy/:source/:target
files-copy;POST;Copy files from one site environment to another;/sites/:site/files-copy/:source/:target
