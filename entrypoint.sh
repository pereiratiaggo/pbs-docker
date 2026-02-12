#!/bin/bash
set -euo pipefail

# Le o arquivo /config/backup.conf
INCLUDES=()
EXCLUDES=()

while IFS= read -r line || [ -n "$line" ]; do
  line="$(echo "$line" | sed 's/[\r\n]\+//g')"
  # ignora comentarios e linhas vazias
  if [ -z "$line" ]; then
    continue
  fi
  first_char="${line%%${line#?}}"
  if [ "$first_char" = "#" ]; then
    continue
  fi

  # separa includes e excludes (linha iniciada com '!')
  if [ "$first_char" = "!" ]; then
    EXCLUDES+=("${line#?}")
  else
    INCLUDES+=("$line")
  fi
done < /config/backup.conf

# Adiciona exclusões padrões da variável DEFAULT_EXCLUDES (se definida)
if [ -n "${DEFAULT_EXCLUDES:-}" ]; then
  for ex in $DEFAULT_EXCLUDES; do
    EXCLUDES+=("$ex")
  done
fi

# Monta flags extras opcionais vindas do .env
EXTRA_FLAGS=()
if [ -n "${BACKUP_TYPE:-}" ]; then
  EXTRA_FLAGS+=("--backup-type" "$BACKUP_TYPE")
fi
if [ -n "${BACKUP_ID:-}" ]; then
  EXTRA_FLAGS+=("--backup-id" "$BACKUP_ID")
fi
if [ -n "${ALL_FILE_SYSTEMS:-}" ]; then
  EXTRA_FLAGS+=("--all-file-systems" "$ALL_FILE_SYSTEMS")
fi
if [ "${DRY_RUN:-false}" = "true" ]; then
  EXTRA_FLAGS+=("--dry-run" "true")
fi

if [ ${#INCLUDES[@]} -eq 0 ]; then
  echo "Nenhum include definido em /config/backup.conf" >&2
  exit 1
fi

for inc in "${INCLUDES[@]}"; do
  # formato esperado: archive.pxar:/host/path
  archive="${inc%%:*}"
  path="${inc#*:}"
  if [ -z "$archive" ] || [ -z "$path" ]; then
    echo "Formato inválido de include: $inc" >&2
    continue
  fi

  # monta argumentos de exclude relativos ao path do include
  EXCLUDE_ARGS=()
  for ex in "${EXCLUDES[@]}"; do
    case "$ex" in
      "$path"* )
        rel="${ex#$path}"
        # remove / inicial se houver
        rel="${rel#/}"
        EXCLUDE_ARGS+=("--exclude" "$rel")
        ;;
      *) ;;
    esac
  done

  echo "Executando backup para $archive do caminho $path"
  # Constrói o comando com array para evitar problemas de word-splitting
  CMD=("backup" "${archive}:${path}")

  # deduplica exclusões mantendo ordem
  if [ ${#EXCLUDES[@]} -gt 0 ]; then
    declare -A __seen_excludes || true
    DEDUP_EX=()
    for ex in "${EXCLUDES[@]}"; do
      if [ -z "${__seen_excludes[$ex]:-}" ]; then
        __seen_excludes[$ex]=1
        DEDUP_EX+=("$ex")
      fi
    done
    for ex in "${DEDUP_EX[@]}"; do
      CMD+=("--exclude" "$ex")
    done
  fi

  # adiciona flags extras
  if [ ${#EXTRA_FLAGS[@]} -gt 0 ]; then
    CMD+=("${EXTRA_FLAGS[@]}")
  fi

  CMD+=("--repository" "${PBS_REPOSITORY}")
  # Autenticação: preferir keyfile em /data/key.pem. Só adiciona se existir.
  if [ -f /data/key.pem ]; then
    CMD+=("--keyfile" "/data/key.pem")
  else
    echo "/data/key.pem não encontrado — o cliente tentará autenticar sem keyfile"
  fi

  # mostra o comando (uma linha) e executa
  printf 'Comando: proxmox-backup-client'
  for a in "${CMD[@]}"; do printf ' %q' "$a"; done
  echo

  proxmox-backup-client "${CMD[@]}"
done
