# docker-couchdb2a-cloudant-fts
Docker Couchdb 2 Alpha cloudant full text search Lucene (Dreyfus and Clouseau)

<h2>Build</h2>

<h3>Build the image</h3>
sudo docker build -t img/couchdb2-cfts .
<h3>Run Container</h3>
sudo docker run -it -p 5984:5984 --user root --name couchdb2-cfts img/couchdb2-cfts

<h3>Start Container</h3>
sudo docker start -i couchdb2-cfts

<h2>Run bash commands inside the container</h2>

<h3>Start CouchDB</h3>
/usr/src/couchdb/dev/run --with-admin-party-please --with-haproxy

<h3>Start Clouseau</h3>
cd /usr/src/clouseau 
mvn scala:run -Dlauncher=clouseau1 & mvn scala:run -Dlauncher=clouseau2 & mvn scala:run -Dlauncher=clouseau3

