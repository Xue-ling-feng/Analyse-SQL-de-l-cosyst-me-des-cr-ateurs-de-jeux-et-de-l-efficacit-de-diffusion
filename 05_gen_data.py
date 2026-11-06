"""Générateur de jeu de données simulé pour l'analyse de l'écosystème des créateurs de jeux (petit échantillon, reproductible, tendances contrôlées)

Principes de conception :
1. Chaque créateur dispose d'un momentum de croissance mensuel stable ; les vues mensuelles évoluent selon (1+momentum)^(t-1) ;
2. L'objectif de vues mensuelles est ensuite réparti entre les publications du mois, afin d'éviter que le nombre de publications ne fausse directement la variation mensuelle ;
3. Le taux de conversion en inscription diffère selon le type de contenu et la plateforme, pour que les conclusions métier par catégorie / plateforme soient cohérentes.
"""
import csv, random, os
from datetime import datetime, timedelta


random.seed(20261106)
BASE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.join(BASE, "dataset")
os.makedirs(DS, exist_ok=True)


PLATFORM_CREATORS = {"Douyin": 24, "Bilibili": 20, "MiHoYo Community": 9, "TapTap": 7}
VIEW_BASE = {"Douyin": (35000, 150000), "Bilibili": (22000, 110000),
             "MiHoYo Community": (10000, 55000), "TapTap": (9000, 42000)}
FANS = {"Douyin": (15000, 450000), "Bilibili": (12000, 320000),
        "MiHoYo Community": (5000, 150000), "TapTap": (4000, 90000)}
TYPE_WEIGHTS = {
    "Douyin":    {"Création dérivée": .38, "Gameplay": .30, "Guide de personnage": .18, "Guide de mise à jour": .14},
    "Bilibili":  {"Guide de personnage": .30, "Guide de mise à jour": .26, "Création dérivée": .26, "Gameplay": .18},
    "MiHoYo Community": {"Guide de personnage": .34, "Guide de mise à jour": .30, "Gameplay": .20, "Création dérivée": .16},
    "TapTap": {"Guide de personnage": .34, "Guide de mise à jour": .32, "Gameplay": .22, "Création dérivée": .12},
}
TYPE_VIEW_MULT = {"Création dérivée": 1.70, "Gameplay": 1.15, "Guide de personnage": 1.00, "Guide de mise à jour": 0.92}
TYPE_SHARE_MULT = {"Création dérivée": .075, "Gameplay": .045, "Guide de mise à jour": .038, "Guide de personnage": .032}
TYPE_CONV_RATE = {"Guide de mise à jour": .00145, "Guide de personnage": .00100, "Gameplay": .00078, "Création dérivée": .00052}
PLATFORM_CONV = {"Douyin": .85, "Bilibili": 1.20, "MiHoYo Community": 1.35, "TapTap": 1.10}
BUDGET = {"Douyin": (1500, 8000), "Bilibili": (1200, 6500),
          "MiHoYo Community": (800, 4000), "TapTap": (700, 3500)}
GAMES = {"Genshin Impact": .42, "Honkai: Star Rail": .36, "Zenless Zone Zero": .22}
REGIONS = ["Chine continentale", "Hong Kong, Macao et Taïwan", "Asie du Sud-Est", "Japon et Corée du Sud"]
MONTHLY_SCALE = 0.55          # Contrôle le volume mensuel de vues pour garder un nombre raisonnable de conversions
END_MONTH = 10                # Les données couvrent la période de janv. 2026 à oct. 2026



def pick_weighted(d):
    r, acc = random.random(), 0.0
    for k, w in d.items():
        acc += w
        if r <= acc:
            return k
    return list(d)[0]



def level_of(f):
    if f < 30000: return "L1"
    if f < 80000: return "L2"
    if f < 180000: return "L3"
    if f < 350000: return "L4"
    return "L5"



def month_end(y, m):
    nm = datetime(y + (m // 12), (m % 12) + 1, 1)
    return nm - timedelta(seconds=1)



creators, posts, converts, campaigns = [], [], [], []
seq_content = seq_conv = seq_camp = 0


for platform, n_creator in PLATFORM_CREATORS.items():
    lo_v, hi_v = VIEW_BASE[platform]
    monthly_mid = (lo_v + hi_v) / 2 * MONTHLY_SCALE
    for i in range(1, n_creator + 1):
        creator_id = f"C{platform}{i:03d}"
        fans = random.randint(*FANS[platform])
        # 20 % des créateurs sont nouveaux en 2026, pour générer des échantillons en phase débutant
        if random.random() < 0.20:
            reg = datetime(2026, random.randint(5, 9), random.randint(1, 28))
        else:
            reg = datetime(2024, 1, 1) + timedelta(days=random.randint(0, 730))
        creators.append([creator_id, platform, level_of(fans), reg.date().isoformat(), fans])


        momentum = max(-0.25, min(0.30, random.gauss(0.03, 0.13)))
        start_month = max(1, (reg.year - 2026) * 12 + reg.month)
        if start_month > END_MONTH:      # Les inscrits d'octobre commencent en octobre
            start_month = END_MONTH


        for m in range(start_month, END_MONTH + 1):
            k = random.randint(1, 3)                      # Nombre de publications du mois
            monthly_target = monthly_mid * (1 + momentum) ** (m - 1) * random.uniform(0.97, 1.03)
            types = [pick_weighted(TYPE_WEIGHTS[platform]) for _ in range(k)]
            weights = [TYPE_VIEW_MULT[t] * random.uniform(0.90, 1.10) for t in types]
            wsum = sum(weights)


            for j in range(k):
                seq_content += 1
                content_id = f"CT{seq_content:05d}"
                ctype = types[j]
                views = max(1000, int(monthly_target * weights[j] / wsum))
                likes = int(views * random.uniform(0.020, 0.060))
                shares = int(views * TYPE_SHARE_MULT[ctype] * random.uniform(0.8, 1.2))
                base = datetime(2026, m, 1)
                pub = base + timedelta(seconds=random.randint(0, int((month_end(2026, m) - base).total_seconds() / 5)))
                pub -= timedelta(0)
                posts.append([content_id, creator_id, pick_weighted(GAMES), ctype,
                              pub.strftime("%Y-%m-%d %H:%M:%S"), views, likes, shares])


                n_reg = int(views * TYPE_CONV_RATE[ctype] * PLATFORM_CONV[platform]
                            * random.uniform(0.75, 1.30))
                for _ in range(n_reg):
                    seq_conv += 1
                    converts.append([seq_conv, content_id, f"U{random.randint(1, 900000):06d}",
                                     "register",
                                     (pub + timedelta(hours=random.randint(1, 240))).strftime("%Y-%m-%d %H:%M:%S")])


                if random.random() < 0.25:                   # Environ 1 contenu sur 4 bénéficie d'une campagne payante, un plan par contenu
                    seq_camp += 1
                    blo, bhi = BUDGET[platform]
                    budget = round(random.uniform(blo, bhi) * (1 + fans / 900000), 2)
                    campaigns.append([f"CP{seq_camp:04d}", content_id, budget,
                                      (pub + timedelta(days=random.randint(0, 3))).date().isoformat(),
                                      random.choice(REGIONS)])


# Supprime les doublons d'utilisateur sur un même contenu pour éviter des enregistrements de conversion incohérents
seen, uniq = {}, []
for row in converts:
    bucket = seen.setdefault(row[1], set())
    if row[2] in bucket:
        continue
    bucket.add(row[2])
    uniq.append(row)
for i, row in enumerate(uniq, 1):
    row[0] = f"CV{i:07d}"


FILES = [
    ("dim_creator.csv", ["creator_id", "platform", "account_level", "register_time", "fan_count"], creators),
    ("dwd_content_post.csv", ["content_id", "creator_id", "game_category", "content_type",
                              "publish_time", "view_count", "like_count", "share_count"], posts),
    ("dwd_user_convert.csv", ["convert_id", "content_id", "user_id", "convert_type", "convert_time"], uniq),
    ("dwd_campaign_put.csv", ["campaign_id", "content_id", "budget", "put_time", "target_region"], campaigns),
]
for name, header, rows in FILES:
    with open(os.path.join(DS, name), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


print("=== Taille du jeu de données ===")
for name, header, rows in FILES:
    print(f"{name:24s} {len(rows):>8,} lignes")
print(f"{'Total':24s} {sum(len(r) for _, _, r in FILES):>8,} lignes")
