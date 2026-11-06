"""Importation automatique des quatre CSV du dossier dataset/ dans MySQL (exécuter d'abord 01_create_table.sql)

Utilisation :
    pip install pymysql
    python 04_load_csv.py --host 127.0.0.1 --port 3306 --user root --password VotreMotDePasse --db game_creator
"""
import argparse, csv, os, sys


BASE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.join(BASE, "dataset")


TABLES = [
    ("dim_creator", "creator_id, platform, account_level, register_time, fan_count", 5),
    ("dwd_content_post", "content_id, creator_id, game_category, content_type, publish_time, "
                         "view_count, like_count, share_count", 8),
    ("dwd_user_convert", "convert_id, content_id, user_id, convert_type, convert_time", 5),
    ("dwd_campaign_put", "campaign_id, content_id, budget, put_time, target_region", 5),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=3306)
    ap.add_argument("--user", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--db", default="game_creator")
    ap.add_argument("--charset", default="utf8mb4")
    args = ap.parse_args()


    import pymysql
    conn = pymysql.connect(host=args.host, port=args.port, user=args.user,
                           password=args.password, charset=args.charset, autocommit=False)
    cur = conn.cursor()
    cur.execute(f"CREATE DATABASE IF NOT EXISTS `{args.db}` "
                f"DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci")
    cur.execute(f"USE `{args.db}`")


    for name, cols, ncol in TABLES:
        path = os.path.join(DS, f"{name}.csv")
        with open(path, encoding="utf-8") as f:
            rows = list(csv.reader(f))[1:]
            ph = ",".join(["%s"] * ncol)
            cur.executemany(f"INSERT INTO {name} ({cols}) VALUES ({ph})", rows)
            conn.commit()
            print(f"{name:22s} importé : {len(rows):>7,} lignes")


    cur.close()
    conn.close()
    print("\nImport terminé, vous pouvez exécuter 02_analysis_queries.sql pour reproduire les résultats du rapport.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("Échec de l'import :", e, file=sys.stderr)
        sys.exit(1)
