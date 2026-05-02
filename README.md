# AWS_study

AWSの基礎構築を学ぶ

## フォルダ構成

```
AWS_study/
├── .gitignore
├── .terraform.lock.hcl
├── README.md
├── case1/                      # 構成1: EC2単体
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tf
│   └── variables.tf
├── case2/                      # 構成2: EC2 + RDS + ALB + CloudFront
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tf
│   └── variables.tf
└── case3/                      # 構成3: ECS + RDS + ALB + CloudFront
    ├── .terraform.lock.hcl
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tf
    └── variables.tf
```

## 構成一覧

### 構成1 — EC2単体（WordPress + MySQL 同居）

単一のEC2インスタンス上にWordPressとMySQLを同居させたシンプルな構成

- **EC2**: WordPress + MySQL（MariaDB）をインストール

### 構成2 — EC2 + RDS + ALB + CloudFront

DBをRDSに分離し、ALBによる負荷分散とCloudFrontによるキャッシュ配信を追加した構成

- **EC2**: WordPressのみ（DBは持たない）
- **RDS**: マネージドMySQL（バックアップ・パッチ適用はAWSが管理）
- **ALB**: 複数EC2へのトラフィック分散・高可用性
- **CloudFront**: 静的コンテンツのキャッシュ配信・レイテンシ削減

### 構成3 — ECS + RDS + ALB + CloudFront

コンテナ化によりインフラ管理をさらに省力化した構成

- **ECS（Fargate）**: コンテナ化されたWordPressを実行（サーバー管理不要）
- **RDS**: マネージドMySQL
- **ALB**: コンテナへのトラフィック分散
- **CloudFront**: 静的コンテンツのキャッシュ配信・レイテンシ削減
