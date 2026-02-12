#!/bin/sh
set -euo pipefail

# Le o arquivo /config/backup.conf
INCLUDES=()
EXCLUDES=()

while IFS= read -r line || [ -n "$line" ]; do
  line="$(echo "$line" | sed 's/[\r\n]\+//g')"
  # ignora comentarios e linhas vazias
  case "$line" in
    ''|#*) continue ;;
  esac
  case "$line" in
    !*) EXCLUDES+=("${line#!}") ;;
    *) INCLUDES+=("$line") ;;
  esac
done < /config/backup.conf

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
  echo "Exclusões aplicadas: ${EXCLUDE_ARGS[*]:-none}"

  proxmox-backup-client backup \
    "$archive:$path" \
    ${EXCLUDE_ARGS:+${EXCLUDE_ARGS[@]}} \
    --repository "${PBS_REPOSITORY}" \
    --password "${PBS_PASSWORD}" \
    --fingerprint "${PBS_FINGERPRINT}" \
    --keyfile /data/key.pem \
    --verbose
done
