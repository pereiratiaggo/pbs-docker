# PBS Docker Backup

Este repositório contém um container para executar backups com o `proxmox-backup-client`.

Arquivos principais:
- `docker-compose.yml` — define o serviço `pbs-client`.
- `Dockerfile` — constrói a imagem local `pbs-client-local` (base: `fdrake/proxmox-backup-client`).
- `entrypoint.sh` — wrapper que lê `backup.conf` e executa o cliente por include, aplicando excludes.
- `backup.conf.example` — exemplo de includes/excludes.
- `.env` / `.env.example` — variáveis de ambiente (PBS, HOSTNAME_ID, DEFAULT_EXCLUDES, DRY_RUN).

Uso rápido:

1. Copie os exemplos e ajuste valores:

```bash
cp .env.example .env
cp backup.conf.example backup.conf
```

2. (Opcional) Coloque sua chave em `./data/key.pem` para autenticação com `--keyfile`.

3. Construir e rodar (modo seguro com `DRY_RUN=true`):

```bash
docker compose build
docker compose up
```

Para executar efetivamente (faça backup real), ajuste em `.env`: `DRY_RUN=false` e rode novamente.

Observações:
- Paths em `backup.conf` seguem o que o container vê: se você monta `/` em `/host`, use `/host/...` para apontar para `/home` do host.
- Exclua caminhos no `backup.conf` prefixando a linha com `!`, por exemplo: `!/host/home/tiago/ResilioSync`.
