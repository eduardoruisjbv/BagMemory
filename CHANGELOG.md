# 0.2.5 — Análise ao abrir bolsas

- Ouvintes de mudanças de inventário, carregamento de dados e equipamento são registrados somente enquanto uma bolsa nativa está aberta e desligados ao fechar a última bolsa.
- Abrir uma bolsa relê o inventário; fechar antes do scan agendado cancela a análise de fundo.
- Varreduras de fundo por missões/login/especialização também aguardam a abertura das bolsas.
- Interações diretas com vendedor/banco/AH e comandos manuais continuam lendo os dados necessários às operações autorizadas.
- Ícones de bolsas ocultas não fazem consultas desnecessárias.
- Validação no cliente pendente; sem medição de CPU nesta atualização.

# 0.2.4 — Menos varreduras e custo de CPU

- Eventos de dados de itens agora só provocam varredura quando o BagMemory aguarda aquele ID.
- Solicitações pendentes são reutilizadas; falhas de carregamento não disparam ciclos de reanálise.
- Varreduras automáticas são adiadas durante combate e reunidas ao sair, em uma janela de 0,25 s.
- Padrões localizados de tooltip e tabelas constantes são preparados uma vez.
- Vínculos, missões, reembolso, PvP e regras de venda continuam sendo lidos/classificados com dados atuais.
- Validação visual e medição de desempenho no cliente ainda pendentes.

# 0.2.3 — Bando de Guerra e equipamento separado

- Adiciona **Permitir venda de itens do Bando de Guerra**, desligado por padrão e salvo por personagem.
- A opção ignora somente a proteção de conta/Bando de Guerra; a venda segue as demais regras e preserva missões, heranças, melhores da categoria, proteção manual e dados incertos.
- Equipamentos de conta/Bando de Guerra não seguem para AH mesmo antes do vínculo ao personagem; com bypass ativo, podem seguir as regras normais de venda ao NPC. Materiais continuam preservados automaticamente.
- Alterar a opção interrompe a fila anterior e atualiza imediatamente classificação, dessaturação e candidatos do vendedor; cada envio continua revalidando o item.
- Remove sugestões, botão Equipar, contexto Auto/PvE/PvP e troca automática de equipamento. Full Auto gerencia banco, missões de itens e vendas, sem mexer nos itens vestidos.
- Mantém leitura de equipamentos vestidos e proteção comparativa PvE/PvP; compatibilidade de classe fica em ClassRules.lua.
- Migra preferências antigas de equipamento e limpa sugestões gravadas em snapshots do banco.
- Sintaxe Lua conferida sem executar módulos ou testes; validação no cliente WoW permanece pendente.

# 0.2.2 — Classe e vendas em lotes

- Melhor da categoria passa a excluir equipamentos inadequados à classe.
- Armaduras incompatíveis vinculadas ao personagem são vendáveis independentemente de ilvl, PvP, melhorias ou aparência; preserva missões, heranças, itens especiais e proteções explícitas.
- Itens vinculados à tropa/conta ganham Sugerir banco de guerra e não são vendidos nem depositados automaticamente no banco pessoal.
- Troca a fila sequencial por lotes nativos de até 12 vendas, com confirmação conjunta pelas bolsas e recompra.
- Eventos de bolsas/vendedor acionam confirmação; próximas vendas não esperam intervalos individuais.
- Recusas intactas têm tentativas limitadas em lotes menores; ambiguidades interrompem a fila.
- Mantém 12 vendas por interação no Semi Auto; Full Auto autorizado continua todos os candidatos.
- Sintaxe Lua verificada; desempenho real e interações do cliente ainda precisam de validação em WoW.

# 0.2.1 — Ritmo e diagnóstico de vendas

- Retira a análise global repetida por pilha; usa verificação leve do inventário e releitura do item antes da venda.
- Eventos de alterações próprias das bolsas não refazem toda a análise durante a fila; mudanças externas invalidam o contexto.
- Reduz as esperas programadas de venda, mantendo confirmação de remoção global e recompra.
- Recusa do jogo com item intacto deixa os demais candidatos prosseguirem; remoção ambígua continua exigindo revisão.
- Mostra modo, progresso e parada pelo limite do Semi Auto; Full Auto autorizado continua sem limite de 12.
- Equipamentos comprovadamente inferiores aos melhores carregados/vestidos não exigem visita prévia ao banco; registros antigos do banco não justificam descartes.
- Adiciona /bm diagnostico com versão e motivos das pilhas restantes.
- Verificação de sintaxe Lua; medição de desempenho e operação no cliente ainda necessárias.

# 0.2.0 — Banco, missões e equipamentos

- Semi Auto gerencia mochila/banco; Full Auto acrescenta equipamentos e missões de itens, com autorização explícita por personagem.
- Leitura completa do banco participa da proteção do melhor equipamento; registros antigos impedem venda de equipamentos.
- Depósito de itens armazenáveis, retirada de vendáveis e dessaturação no banco pessoal da Blizzard.
- Missões/iniciadores excluídos da venda; itens ativos disponíveis na mochila; aceitação da oferta exata do item no Full Auto.
- Sugestões por classe, armadura, especialização, atributos, slots, armas e limites únicos; botão Equipar sugestões no Semi Auto.
- Trocas nativas fora de combate no Full Auto, confirmação de identidade e revisão para efeitos/conjuntos/proteções.
- Contexto de equipamento Auto/PvE/PvP e visualização dos itens vestidos.
- Full Auto pode ultrapassar as 12 entradas de recompra; pausa, revogação e bloqueios interrompem filas.
- Beta: validação das novas operações no cliente WoW ainda pendente.

# 0.1.0 — Initial beta

- Character-first cleanup based on equipped item level and a configurable margin.
- Best-in-category protection across carried and equipped items, including ties and paired slots.
- Separate PvE/PvP comparisons, localized PvP tooltip parsing and conservative PvP preservation.
- Automatic vendor batches, buyback confirmation and repair with optional guild funds.
- Recent auction observations for low-profit vendor decisions; native auction preparation.
- Blizzard bag desaturation, per-character rules, searchable preview and sale history.
- Preserve heirlooms, equipment sets, uncollected appearances, special items and uncertain data.
