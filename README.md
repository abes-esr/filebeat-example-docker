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

Chaque application qui est déployée avec docker et qui produit des logs (c'est à dire toutes les applis ?), doit les produire de la même façon et indiquer au démon filebeat comment les récupérer pour qu'il puisse ensuite les envoyer correctement au puits de log (logstash / elasticsearch / kibana).

L'application doit respecter quelques règles :

1) produire ses logs à surveiller sur stdout et stderr
2) paramétrer filebeat avec des labels docker
3) produire ses logs personnalisées en respectant un format

#### stderr stdout

Pour que le conteneur de l'application produire ses logs sur stdout et stderr, il y a plusieurs possibilités ... TODO expliquer

#### paramètres pour filebeat - labels docker

Le paramétrage de la remontée des logs dans filebeat se fait au niveau de chaque conteneur en suivant une nomenclature de "labels docker" (cf [recommandations](https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html#_customize_your_configuration)).

La configuration la plus simple est de seulement signaler à filebeat que les logs du conteneur sont à prendre en compte en indiquant aucun format de log. Pour cela il est nécessaire d'ajouter les labels suivant au conteneur. Voici un extrait à copier coller dans un `docker-compose.yml` qui montre comment signaler à filebeat de prendre les logs en compte :
```
    labels:
      - "co.elastic.logs/enabled=true"
      - "co.elastic.logs/processors.add_fields.target="
      - "co.elastic.logs/processors.add_fields.fields.abes_appli=monapplication"
      - "co.elastic.logs/processors.add_fields.fields.abes_middleware=Httpd"
```

Les labels ont la signification suivante :
- `co.elastic.logs/enabled=true` : signifie qu'on souhaite que filebeat remonte les logs de ce conteneur (par défault c'est `false`)
- `co.elastic.logs/processors.add_fields.target=` : signifie qu'on souhaite ajouter les deux champs `abes_appli` et `abes_middleware` dans le puits de logs en rateau à la racine des champs (cf [la doc](https://www.elastic.co/guide/en/beats/filebeat/current/add-fields.html#add-fields))
- `co.elastic.logs/processors.add_fields.fields.abes_appli=monapplication` : signifie qu'on souhaite faire remonter un champs personnalisé nommé "abes_appli" qui contiendra comme valeur "monapplication" pour le conteneur présent. Ce champ "abes_appli" est obligatoire, il doit contenir le nom de l'application car cette dernière peut être éclatée en plusieurs conteneurs (un pour le web, un pour le back, un pour les batch etc ...), c'est ce champ qui permet de regrouper tous les conteneur d'une même application au niveau du puits de logs. Remarque : dans une architecture de type orchestrateur (ex: OKD), c'est probablement le nom du pod qui remplacera la valeur de "abes_appli".
- `co.elastic.logs/processors.add_fields.fields.abes_middleware=Httpd` : le champs "abes_middleware" est obligatoire, il permet d'indiquer au puits de logs de l'Abes (via logstash précisément) la nature des logs envoyées et donc dans quel index elasticsearch doit il classer ces logs. Les valeurs possibles sont : "Httpd", _à compléter_.

Pour un exemple complet, on peut se référer à https://github.com/abes-esr/abes-filebeat-docker/blob/f4b19dfdccab690801c550c61724bd09cbeb6f5b/docker-compose.yml#L24-L37
On trouve alors d'autres labels dont voici la signification :
- `co.elastic.logs/module=nginx` : signifie qu'on dit à filebeat que ce conteneur produit des logs au format nginx ce qui lui permettra de les envoyées découpées dans le puits de logs (cf la liste des [modules filebeat disponibles](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html))
- `co.elastic.logs/fileset.stdout=access` : signifie que filebeat doit surveiller les logs stdout du conteneur
- `co.elastic.logs/fileset.stderr=error` : signifie que filebeat doit surveiller les logs stderr du conteneur

#### format pour les log personnalisées

TODO expliquer ici que les appli java/métier doivent produire des logs spécifique en respectant certaines règles, lister les règles, donner des exemple de configuration de log4j etc ...
