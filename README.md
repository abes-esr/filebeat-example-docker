# filebeat-example-docker

Exemple de configuration pour utiliser filebeat pour surveiller les logs de conteneurs docker en se basant sur les recommandations https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html

## Pre-requis

### Réglages systèmes 
Pour que la pile ELK fonctionne suivre ces instructions :
https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#_set_vm_max_map_count_to_at_least_262144

La partie importante étant :
```
sysctl -w vm.max_map_count=262144
```

### Initialisation des indexes dans ELK pour filebeat

A faire une seule fois pour préparer ELK à recevoir des logs venant de filebeat.

cf https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html#_run_the_filebeat_setup

```
# ces deux lignes ne sont pas forcément nécessaires, elles permettent de préparer
# elasticsearch a gérer des données dans un espace restreint (pas bcp de disque dispo)
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

On lance ensuite filebeat et l'application exemple (un conteneur avec nginx + un conteneur pour un batch qui produit des logs personnalisées) :
```
cd ../myapp/
docker-compose up -d
```

Si on veut simuler des requêtes sur le serveur web de l'application exemple, on peut le faire comme ceci :
```
curl http://127.0.0.1:8080
```

On peut ensuite aller consulter les logs remontés dans elasticsearch/kibana en se connectant sur : http://127.0.0.1:5601/app/discover

## Explications et observations

On remarque que le conteneur web qui va générer des logs au format nginx (nommé `myapp-web`) va être correctement parsé par [le module nginx de filebeat](https://github.com/kerphi/filebeat-example-docker/blob/main/myapp/docker-compose.yml#L11-L15). Et on remarque au passage que les logs qui ne sont pas au format nginx sont également remontées par filebeat :

<img src="https://user-images.githubusercontent.com/328244/127513686-803c6684-8a4a-4d33-a2a3-f4ce0c03a7c4.png" width="500px" />



On remarque que le conteneur batch chargé de produire des logs personnalisées (nommé `myapp-with-customlog`) est correctement parsé par [le tokenizer fourni par filebeat](https://github.com/kerphi/filebeat-example-docker/blob/main/myapp/docker-compose.yml#L25-L27). Les logs parsées sont ensuite disponibles dans les champs `dissect.status` et `dissect.message` dans kibana.

<img src="https://user-images.githubusercontent.com/328244/127512443-3e083071-46fc-42e7-9ea5-9c646dbfef33.png" width="500px" />

On remarque que des champs "abes.appli" et "abes.source" peuvent être remontés par filebeats (en conservant une configuration globale au serveur) et [personnalisé par chaque conteneur à l'aide du système de labels](https://github.com/kerphi/filebeat-example-docker/blob/main/myapp/docker-compose.yml#L31-L36). Ceci permet de regrouper facilement les conteneur d'une même appli au niveau du puits de logs :

![image](https://user-images.githubusercontent.com/328244/128374129-3d397b19-30c3-4036-aa69-ce11f181f443.png)

