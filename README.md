# Projet d'analyse SQL : écosystème des créateurs de jeux et efficacité des diffusions de contenu

> Projet d'analyse métier simulé. L'ensemble des données sont un jeu de données simulé construit à la main, ce ne sont pas des données métier réelles.
> Chaque tableau de résultat de requête du rapport correspond à la sortie obtenue après exécution réelle des requêtes SQL du paquet sur ce jeu de données ; il est possible de reproduire ligne par ligne les résultats.

## I. Contenu du paquet

| Fichier | Description |
|---|---|
| `Rapport_projet_analyse_SQL_ecosysteme_createurs_jeux.pdf` | Rapport du projet : contexte, modèle de données, les cinq requêtes SQL et leurs sorties réelles, conclusions métier |
| `01_create_table.sql` | Script de création des quatre tables et des index (MySQL 8.0+) |
| `02_analysis_queries.sql` | Les cinq requêtes d'analyse principales, marquées par `-- @query qN`, exécutables séparément |
| `03_query_outputs/` | Résultats d'exécution réels des cinq requêtes ci-dessus (CSV), correspondant un à un aux tableaux du rapport |
| `04_load_csv.py` | Script auxiliaire pour importer automatiquement les fichiers CSV dans MySQL |
| `dataset/` | Les quatre fichiers CSV de données brutes |
| `05_gen_data.py` | Script de génération des données simulées ; il est possible d'augmenter la taille de l'échantillon en modifiant les paramètres |

## II. Taille du jeu de données

| Table | Nombre de lignes | Description |
|---|---|---|
| dim_creator | 60 | Dimension des créateurs : 24 sur Douyin / 20 sur Bilibili / 9 sur MiHoYo Community / 7 sur TapTap |
| dwd_content_post | 997 | Publications de contenu, du 2026-01-01 au 2026-10-31 |
| dwd_user_convert | 23 605 | Événements de conversion par inscription ; `user_id` unique pour un même contenu |
| dwd_campaign_put | 237 | Plans de diffusion payante : un seul plan par contenu, budget total de 1 063 000 yuans |
| **Total** | **24 899** | |

Il s'agit d'un volume de démonstration, pas d'un jeu de données massif : le volume reste maîtrisé, les résultats sont vérifiables, et chaque requête produit une distribution suffisante pour étayer les conclusions métier.

## III. Procédure de reproduction

**Méthode A : import par script (recommandée)**

```bash
pip install pymysql
python 04_load_csv.py --user root --password 你的密码 --db game_creator
```

Exécutez ensuite les cinq requêtes du fichier `02_analysis_queries.sql`.

**Méthode B : import manuel**

1. Créez la base de données `game_creator` dans MySQL (encodage `utf8mb4`) ;
2. Exécutez `01_create_table.sql` pour créer les tables ;
3. Utilisez l'assistant *Table Data Import Wizard* de MySQL Workbench, et importez les CSV dans l'ordre suivant :
`dim_creator` → `dwd_content_post` → `dwd_user_convert` → `dwd_campaign_put`

> 
> L'ordre d'import ne doit pas être inversé : les tables suivantes dépendent des `creator_id` / `content_id` des tables précédentes.

## IV. Points clés de conception des cinq requêtes SQL

1. **Indicateurs de valeur clé des créateurs** : le nombre de publications et le nombre d'inscriptions sont préagrégés dans des CTE séparées, afin d'éviter que la jointure directe entre la table de contenus et la table de conversions ne multiplie artificiellement le nombre de vues.
2. **Segmentation du cycle de vie** : on réduit d'abord la granularité à « créateur × mois » dans une CTE et on calcule à l'avance le nombre de mois actifs. Sans cette étape, le filtre `WHERE` sur un seul mois ramènerait systématiquement le nombre de mois actifs à 1, et tous les créateurs seraient faussement classés dans la catégorie « débutant ».
3. **Évaluation de la valeur par type de contenu** : les vues, les inscriptions et les budgets sont agrégés séparément puis joints, pour empêcher la répétition du budget liée au détail des conversions.
4. **Surveillance de l'écosystème par plateforme** : la part relative est calculée avec la fonction de fenêtrage `SUM(...) OVER ()` sur l'agrégat, sans sous-requête imbriquée supplémentaire.
5. **Sélection des créateurs à haut potentiel** : le classement `RANK()` est effectué au sein de chaque plateforme pour éviter des comparaisons inter-plateformes non pertinentes ; le filtre sur `nombre d'inscriptions ≥ 50` limite les distorsions du CPA causées par les petits échantillons.

## V. Limites connues

- Les données sont générées de manière simulée ; les conclusions sur les plateformes et les types de contenu servent uniquement à valider la cohérence des calculs, elles ne représentent pas des références de marché réelles ;
- La segmentation du cycle de vie repose sur la variation mensuelle d'octobre 2026, les seuils sont des valeurs empiriques ; en contexte métier réel, il faudrait les calibrer sur l'historique de chaque plateforme ;
- La conversion ne prend en compte que l'inscription : les événements de clic et de téléchargement ne sont pas présents, il n'est donc pas possible de calculer l'entonnoir complet ;
- Chaque contenu est associé à un unique plan de diffusion. Sur des données réelles, si un contenu peut avoir plusieurs plans, il faudrait d'abord dédoublonner sur `content_id` avant de calculer le CPA.