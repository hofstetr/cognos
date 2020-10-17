# Cognos in Containers
This will contain my work to implement Cognos Analytics in containers running in a swarm environment. Doing so will make it possible to easily scale Cognos Analtyics where needed. Following along with best practices each component will be run within separate containers.

## Step 1 [Content Store](Content_Store.md)
IBM Cognos Analytics requires a minimum of one database to store metadata. It is strongly encouraged to also provide a database to store audit information. Certain components can be configured to utilize dedicated databases rather than the metadata one but for now the plan is to keep it simple. Only a handful of database platforms are supported. Check 
