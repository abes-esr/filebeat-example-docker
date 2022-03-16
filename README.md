# filebeat-example-docker

Exemple de configuration pour utiliser filebeat pour la surveillance des logs docker en se basant sur les recommandations https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html

Ce dépôt contient un PoC qui permet de tester avec une mini architecture en totale autonomie en local :
- un kibana + elasticsearch (répertoire elk)
- un filebeat + deux applications (répertoire myapp)

Les deux applications générent des logs dans leurs conteneurs docker sur stdout et stderr. Le conteneur filebeat va automatiquement écouter et ces logs au nveau du démon docker de la machine et les envoyer à elasticsearch directement. Le conteneur Kibana permet de visualiser les logs de l'elasticsearch.

```
app1 -> filebeat -> elasticsearch -> kibana
app2 ->
```

A noter : à l'Abes nous utilisons (à la date de septembre 2021) un intermédiaire logstash qui fonctionne de la même manière au niveau de filebeat qui va alors envoyer les logs à logstash plutôt qu'à elasticsearch directement.

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

### Utilisation des modules standards de filebeat

On remarque que le conteneur web qui va générer des logs au format nginx (nommé `myapp-web`) va être correctement parsé par [le module nginx de filebeat](https://github.com/kerphi/filebeat-example-docker/blob/main/myapp/docker-compose.yml#L11-L15). Et on remarque au passage que les logs qui ne sont pas au format nginx sont également remontées par filebeat :

<img src="https://user-images.githubusercontent.com/328244/127513686-803c6684-8a4a-4d33-a2a3-f4ce0c03a7c4.png" width="500px" />

### Traitement de logs spécifiques par filebeat

On remarque que le conteneur batch chargé de produire des logs personnalisées (nommé `myapp-with-customlog`) est correctement parsé par [le tokenizer fourni par filebeat](https://github.com/kerphi/filebeat-example-docker/blob/main/myapp/docker-compose.yml#L25-L27). Les logs parsées sont ensuite disponibles dans les champs `dissect.status` et `dissect.message` dans kibana.

<img src="https://user-images.githubusercontent.com/328244/127512443-3e083071-46fc-42e7-9ea5-9c646dbfef33.png" width="500px" />

### Remontée de champs personnalisés par conteneur

On remarque que des champs "abes_appli" et "abes_middleware" peuvent être remontés par filebeats (en conservant une configuration globale au serveur) et [personnalisé par chaque conteneur à l'aide du système de labels](https://github.com/kerphi/filebeat-example-docker/blob/644e8d0b0be4d0f1249b656df76a95424453e6f8/myapp/docker-compose.yml#L11-L18). Ceci permet de regrouper facilement les conteneur d'une même appli au niveau du puits de logs :

![image](https://user-images.githubusercontent.com/328244/128502198-fdb569b9-4c6a-46a0-b551-b1a69167c78c.png)

## Exemples de politiques d'infra / dev

### Politique d'infra 

Chaque serveur qui héberge des conteneurs docker possède un conteneur nommé [`abes-filebeat-docker`](https://github.com/abes-esr/abes-filebeat-docker/) qui est une instance de filebeat préconfigurée pour envoyer les logs vers le puits de logs de l'Abes. Cette instance de filebeat a comme rôle de surveiller les logs des conteneurs docker de la machine dont ont en demande la surveillance. Par défaut filebeat est configuré pour ne surveiller aucun conteneur.

### Politique de dev

cf son intégration ici :
https://github.com/abes-esr/abes-politique-developpement/pull/28
