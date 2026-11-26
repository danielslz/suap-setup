# Autocompletar do bash para o suap-setup
# Uso: source <(suap-setup completion bash)

_suap_setup() {
  local cur prev cmd
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  cmd="${COMP_WORDS[1]:-}"

  if [ "${COMP_CWORD}" -eq 1 ]; then
    COMPREPLY=($(compgen -W "menu host docker stack deploy node revert config self-update version completion help --version --help" -- "${cur}"))
    return 0
  fi

  case "${cmd}" in
    host)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "dev prod update redis nginx postgres" -- "${cur}"))
      ;;
    docker)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "dev prod install" -- "${cur}"))
      ;;
    stack)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "redis postgres dockhand arcane arcane-agent haproxy minio" -- "${cur}"))
      ;;
    deploy)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "update status logs restart up down migrate sync-permissions clean-tmp" -- "${cur}"))
      [ "${prev}" = "update" ] && COMPREPLY=($(compgen -W "--migrate" -- "${cur}"))
      ;;
    node)
      if [ "${COMP_CWORD}" -eq 2 ]; then
        COMPREPLY=($(compgen -W "configure" -- "${cur}"))
      else
        COMPREPLY=($(compgen -W "--role" -- "${cur}"))
      fi
      ;;
    revert)
      if [ "${COMP_CWORD}" -eq 2 ]; then
        COMPREPLY=($(compgen -W "host docker stack redis postgres dockhand arcane arcane-agent haproxy minio" -- "${cur}"))
      elif [ "${COMP_CWORD}" -eq 3 ]; then
        case "${prev}" in
          host) COMPREPLY=($(compgen -W "dev prod redis nginx postgres" -- "${cur}")) ;;
          docker) COMPREPLY=($(compgen -W "dev prod install" -- "${cur}")) ;;
          stack) COMPREPLY=($(compgen -W "redis postgres dockhand arcane arcane-agent haproxy minio" -- "${cur}")) ;;
        esac
      fi
      ;;
    config)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "path migrate" -- "${cur}"))
      [ "${COMP_CWORD}" -gt 2 ] && COMPREPLY=($(compgen -W "--from --dry-run" -- "${cur}"))
      ;;
    self-update)
      COMPREPLY=($(compgen -W "--version --check --rollback" -- "${cur}"))
      ;;
    completion)
      [ "${COMP_CWORD}" -eq 2 ] && COMPREPLY=($(compgen -W "bash" -- "${cur}"))
      ;;
  esac
  return 0
}

complete -F _suap_setup suap-setup
