# Sistemas Operativos — Aula Prática: `case` e *globs* no Bash

> **Tema:** Estrutura de decisão `case` e seleção de ficheiros com *globs*  
> **Curso:** Sistemas Operativos • **Duração:** 90–120 min • **Última atualização:** 17-10-2025

---

## Objetivos de Aprendizagem
- Usar `case` para simplificar decisões múltiplas em scripts Bash.
- Aplicar *globs* (`*`, `?`, `[]`, classes POSIX) na seleção de ficheiros e padrões.
- Compreender diferenças entre *globbing*, *brace expansion* e *extended globbing*.
- Escrever scripts robustos com validação de entrada e mensagens de erro.

## Pré-requisitos
- Shell Bash ≥ 4.x (Linux/macOS/WSL).
- Editor de texto (nano, vim, VS Code).
- **Opcional:** `shellcheck` para *lint* de scripts.

## Instalação / Setup rápido
```bash
git clone https://github.com/<org>/<repo>.git
cd <repo>
# Opcional: instalar shellcheck (Debian/Ubuntu)
sudo apt-get install -y shellcheck
