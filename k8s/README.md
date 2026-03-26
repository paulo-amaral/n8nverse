# Kubernetes option

This directory provides a minimal Kubernetes deployment option for `n8n` using:
- external PostgreSQL
- persistent storage for `/home/node/.n8n`
- an Ingress for `https://n8n.localhost`

It does not deploy PostgreSQL inside the cluster.

## Files

- `namespace.yaml`: namespace for the app
- `secret.example.yaml`: template secret for database credentials and encryption key
- `pvc.yaml`: persistent volume claim for n8n data
- `deployment.yaml`: n8n deployment
- `service.yaml`: ClusterIP service for n8n
- `ingress.yaml`: ingress for `n8n.localhost`

## Assumptions

- your cluster already has an Ingress controller, such as ingress-nginx
- your cluster can reach the PostgreSQL host configured in the secret
- TLS for local Kubernetes is controller-specific and should be handled by your local Ingress setup

## Quick start

1. Create the namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

2. Copy and edit the secret template:

```bash
cp k8s/secret.example.yaml k8s/secret.yaml
```

Set:
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `DB_POSTGRESDB_HOST`
- `DB_POSTGRESDB_PORT`
- `N8N_ENCRYPTION_KEY`

Then apply it:

```bash
kubectl apply -f k8s/secret.yaml
```

3. Apply the workload:

```bash
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

4. Make sure `n8n.localhost` resolves to your Ingress endpoint locally.

For many local clusters, `.localhost` already resolves locally without editing `/etc/hosts`.
