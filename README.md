# BagMemory 0.3.0 — WoW Retail

**Bag limpa. Seu melhor equipamento, preservado.** Interface escura com detalhes turquesa, seguindo a direção visual do MuscleMemory.

## Modos e comandos

Abra `/bm` ou `/bagmemory`. A lista mostra mochila, banco e equipamentos vestidos, com destino e motivo. Configurações e autorização pertencem ao personagem.

| Modo | Comportamento |
| --- | --- |
| **Semi Auto**, padrão | Gerencia mochila/banco, vende e repara conforme as opções. Não inicia/aceita missões automaticamente. |
| **Full Auto**, autorizado | Também retira itens de missão necessários do banco e inicia/aceita missões oferecidas pelos itens. Vende todos os candidatos, inclusive além da capacidade da recompra. |

- `/bm full`: autorização com caixa de seleção inicialmente desmarcada e confirmação explícita. O botão do modo revoga e retorna ao Semi Auto.
- `/bm pausa`: suspende ou retoma as operações automáticas.
- `/bm banco`: organiza o banco pessoal acessível.
- `/bm vender`: inicia outro lote com um vendedor aberto.
- `/bm ah`: consulta preços da mochila com a AH aberta.
- `/bm diagnostico`: mostra versão, modo, resumo da venda e os principais motivos dos itens preservados.

A autorização fica salva neste personagem. Ampliação do escopo exige nova confirmação. As regras dos itens podem ser revistas na lista e protegidas manualmente por ID.

## Ilvl e evolução

A faixa de venda usa primeiro **ilvl equipado − margem**, inicialmente **10**, com limite inclusivo. Com 232 equipado e 242 geral, candidatos são itens até 222. Ilvl geral e referência M+2 da temporada são contexto, sem definir descarte.

Antes dessa faixa, compara mochila, banco pessoal e itens vestidos por categoria, tipo e atributos primários. Preserva melhores em PvE/PvP, incluindo empates. Anéis e armas de uso duplo preservam pelo menos duas peças; berloques são protegidos pelos efeitos. Uma calça 220 fica preservada se for sua melhor calça, mesmo com média 232; a 212 pode ser inferior.

Somente equipamentos adequados à classe recebem proteção de melhor da categoria. Armaduras de tecido/couro/malha não são alternativas úteis de armadura para um guerreiro: mesmo com ilvl alto, PvP ou melhorias, peças vinculadas ao personagem passam para venda. Capas, anéis e slots neutros continuam sendo avaliados pela utilidade, sem aplicar a exigência de placas. Armas e atributos consideram as possibilidades da classe inteira, preservando alternativas de outras especializações.

Itens identificados como vinculados ao Bando de Guerra/conta ficam em **Sugerir banco de guerra** por padrão. O checkbox **Permitir venda de itens do Bando de Guerra**, inicialmente desligado e salvo por personagem, ignora somente essa proteção de vínculo. Ao ativá-lo, o item segue as regras normais: pode ser vendido no NPC quando classificado **À venda**, sem se tornar lixo automaticamente. Equipamentos de conta/Bando de Guerra seguem a rota de itens vinculados para venda ao NPC, mesmo quando ainda não vinculados ao personagem; não são enviados para a AH. Materiais de conta continuam preservados automaticamente. Ao desativá-lo, a proteção volta. A mudança cancela a fila anterior, atualiza a classificação e a dessaturação e revalida a venda. Missões, heranças, dados incertos, proteção manual e melhor peça da categoria continuam protegidos. Equipamentos inadequados negociáveis seguem a avaliação de AH; heranças, itens especiais, missões, itens reembolsáveis/trocáveis, conjuntos salvos e proteção manual continuam preservados. Para equipamento comprovadamente inadequado à classe, a aparência não coletada não impede a venda solicitada; essa decisão aparece no motivo da classificação.

Equipamentos inferiores aos melhores da mochila/vestidos podem ser vendidos sem uma visita prévia ao banco. Enquanto o banco não for confirmado, seus registros antigos ficam fora da comparação: nunca justificam descartar a melhor peça conhecida. Abra o banco para incluir suas alternativas; a confirmação permanece após fechar, até alguma mudança invalidá-la. Registros incompletos do banco não autorizam retirar/vender seus itens.

## Equipamento

BagMemory lê os itens vestidos para comparar e preservar os melhores de cada categoria em PvE e PvP. Não sugere trocas, equipa ou move itens vestidos. O gerenciamento de equipamento pertence ao addon independente **GearMemory**; preferências antigas de equipamento e sugestões salvas do BagMemory são descartadas na migração.

## Missões e banco

**Missões e itens iniciadores nunca são vendidos**, inclusive por regra manual. Itens necessários para missões ativas permanecem na mochila. Itens de missões concluídas podem ser armazenados se o banco permitir; necessidade incerta mantém proteção. Semi Auto oferece **Iniciar missão** para usar o item selecionado, deixando a aceitação com o jogador.

Full Auto tenta usar e aceitar somente a missão oferecida pelo item identificado, com espaço no diário. Não aceita indiscriminadamente missões de NPCs nem entrega missões automaticamente. Oferta não confirmada permanece protegida para uso manual.

O organizador deposita **Guardar no banco** primeiro, liberando espaço, e depois retira **À venda**. Full Auto também retira itens necessários/ofertas de missão. Itens sem valor de venda são sugeridos para banco; consumíveis, itens de uso e utilidades permanecem disponíveis. Regras manuais podem solicitar armazenamento quando as proteções permitem.

Somente o **banco do personagem**, nas abas pessoais modernas acessíveis, é gerenciado. Banco da guilda e de guerra/conta não são movimentados. Abra o banco e depois o vendedor: o addon não cria acesso remoto. Falta de espaço, cursor ocupado, combate, dados incompletos ou fechamento de janela interrompem operações.

## Venda, reparo e proteções

Venda, reparo, organização de banco, dessaturação e consultas de AH começam ativados no Semi Auto. **Preservar peças aprimoráveis** também começa ativado.

Semi Auto vende até **12 pilhas por lote**; revise e clique Vender para continuar. Full Auto remove o limite: **vendas além das últimas 12 podem não ser recuperáveis**. Recompra depende do jogo. O histórico de 60 vendas não garante recuperação. Abrir Recompra interrompe a venda automática naquela interação.

Cada venda revalida identidade, quantidade e regras, confirmando remoção/recompra. Reparo exige moedas suficientes. Reparo da guilda é opcional, inicialmente desligado, e exige permissão, saldo e limite.

A análise global é reutilizada enquanto somente as próprias vendas alteram a mochila; mudanças externas exigem nova análise. Cada candidato é relido, mas **até 12 vendas são enviadas no mesmo lote**, sem intervalo individual. Eventos de bolsas/vendedor confirmam o lote pela remoção global e pelas últimas entradas de recompra; um temporizador é apenas contingência para eventos atrasados. Full Auto continua com os lotes seguintes. Recusas com itens intactos têm até duas novas tentativas em lotes menores; remoção ambígua interrompe a fila. Latência e limites do servidor podem reduzir o ritmo. O chat e a janela mostram progresso, modo e motivo da parada.

Heranças, lendários, artefatos, missões, melhores da categoria, PvP identificado, conjuntos salvos, itens de conta (com o checkbox desligado), reembolsáveis/trocáveis, aparências não coletadas, peças de conjunto e berloques têm proteção de venda. Informações incertas ficam para revisão. Regras manuais não removem essas proteções.

## AH e itens antigos

Expansão antiga, isoladamente, não transforma materiais/colecionáveis em lixo. Equipamentos inferiores vinculados podem ser vendidos após as proteções. Materiais/equipamentos negociáveis passam para NPC somente com cotação recente, completa e confirmada da AH.

Compara a pilha inteira pelo preço anunciado menos 5% de comissão contra o NPC. Lucro mínimo inicial: 5 ouro. Cotações expiram em 12 horas e pertencem ao personagem/reino. Sem dados completos ou ofertas, preserva. Preço anunciado não garante venda; esta beta não estima demanda, tempo de venda ou depósito.

Consultas exigem AH aberta e respeitam seu ritmo. **Preparar na AH** seleciona na janela nativa; preço, quantidade, depósito e publicação são confirmados pelo jogador, inclusive no Full Auto. O modo respeita exigências de interação da Blizzard.

## Compatibilidade e validação

Interface 120100, sem bibliotecas obrigatórias. Dessatura todas as peças À venda nas bolsas e no banco pessoal padrão da Blizzard. Interfaces de outros addons precisam de integração específica.

Nesta versão, somente a sintaxe Lua foi conferida com `loadfile`, sem executar os módulos. Nenhum teste de comportamento foi executado. **Validação em WoW ainda necessária:** checkbox, interface, PvP localizado, banco, ofertas de missões, venda/recompra, reparo e convivência com outros addons. A conferência de sintaxe não substitui o cliente. O harness histórico em `tests/run.lua` é anterior à separação do GearMemory.

## Desempenho

As varreduras automáticas de inventário são reunidas em 0,25 s, adiadas durante combate e executadas somente com bolsas abertas. O menu ainda permite atualizar manualmente.

## Análise de inventário

Eventos de itens e varreduras de fundo ficam suspensos com as bolsas nativas fechadas. Abrir uma bolsa atualiza a análise; durante combate a atualização automática aguarda o fim do combate. Operações diretas de vendedor/banco/AH e ações manuais do menu mantêm as leituras necessárias. O GearMemory inicia equipamento automático somente com bolsas abertas; fechar as bolsas interrompe a sequência automática.
