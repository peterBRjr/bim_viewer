---
trigger: always_on
---

* **Visão Geral e Escopo de Negócio:** Mapeamento do fluxo de gestão de projetos (adicionar, visualizar e excluir) e foco na operação offline para canteiros de obra[1][4].
* **Arquitetura Desacoplada (Flutter + ThatOpen Engine):** Especificação da ponte de comunicação (JS Bridge) entre o shell nativo em Flutter e a Viewport 3D WebGL (InAppWebView com WebAssembly/WASM) executando a ThatOpen Engine (`@thatopen/components`)[3].
* **Design System e Semântica de Frontend:** Tabela completa com a paleta de cores semântica (Primary `#0F172A`, Accent `#2563EB`, Background `#F8FAFC`, Surface `#FFFFFF`, Destructive `#EF4444`, Text `#64748B`) e hierarquia tipográfica[7][8].
* **Estrutura de Pastas e Boas Práticas:** Organização em *feature-first* (`home`, `viewer_3d`, `core`), gerenciamento de estado reativo e padrões de desenvolvimento seguro/defensivo[2].