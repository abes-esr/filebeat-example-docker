# filebeat-example-docker

Exemple de configuration pour utiliser filebeat pour surveiller les logs de conteneurs docker

## Pre-requis

### Réglages systèmes 
Pour que la pile ELK fonctionne :
https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#_set_vm_max_map_count_to_at_least_262144


### Initialisation des indexes dans ELK pour filebeat

A faire une seule fois pour préparer ELK à recevoir des logs venant de filebeat.

cf https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html#_run_the_filebeat_setup

```
# ces deux lignes ne sont pas forcément nécessaires, elles permettent de préparer
# elasticsearch a gérer des données dans espace restreint
curl -XPUT -H "Content-Type: application/json" http://localhost:9200/_cluster/settings -d '{ "transient": { "cluster.routing.allocation.disk.threshold_enabled": false } }'
curl -XPUT -H "Content-Type: application/json" http://localhost:9200/_all/_settings -d '{"index.blocks.read_only_allow_delete": null}'

docker run --rm --network=filebeat-example \
docker.elastic.co/beats/filebeat:7.13.4 \
setup -E setup.kibana.host=kibana:5601 \
-E output.elasticsearch.hosts=["elasticsearch:9200"]
```

## Démarrage

On lance en premier elasticsearch et kibana (ces deux elements sont installés sur un serveur indépendant et constituent le puits de logs) :
```
cd elk/
docker-compose up -d
```

On lance ensuite filebeat et l'application exemple (un serveur nginx) :
```
cd ../myapp/
docker-compose up -d
```

Si on veut simuler des requêtes sur le serveur web de l'application exemple, on peut le faire comme ceci :
```
curl http://127.0.0.1:8080
```

On peut ensuite aller consulter les logs remontés dans elasticsearch/kibana en se connectant sur : http://127.0.0.1:5601/app/discover


## TODO

- [ ] faire en sorte que filebeat reconnaisse le format de log de nginx car actuellement ca remonte les lignes de logs sans les parser

