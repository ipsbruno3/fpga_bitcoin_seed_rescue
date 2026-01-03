## Objetivo do projeto

O repositório reúne blocos de hardware escritos em Verilog para recuperar seeds BIP-39 de forma **energicamente eficiente**, usando FPGA/ASIC em vez de clusters de GPU. A ideia é reduzir o custo marginal por tentativa e tornar viáveis recuperações legítimas de carteiras que perderam 2–5 palavras ou pequenas quantias que não justificam infraestruturas caras.

- **Foco:** pipelines SHA-256/SHA-512, derivação PBKDF2-HMAC-SHA512 e geração de palavras BIP-39 a partir de entropia de 128 bits.
- **Uso ético:** somente para recuperação com prova de propriedade e consentimento explícito.

---

## Visão geral dos arquivos

| Arquivo | Papel | O que ele faz |
| --- | --- | --- |
| `generate.sv` | Geração de palavras BIP-39 | Converte 128 bits de entropia + checksum em 12 índices de 11 bits e busca cada palavra na ROM. Inclui `tb_words_stream_12`, um testbench que calcula o checksum via `sha256_firstbyte_128`, aciona o fluxo e imprime a frase completa. |
| `sha256.sv` | SHA-256 compacto (1 bloco) | Implementa `sha256_firstbyte_128`, uma engine simples que processa 128 bits de entropia (mais padding) e expõe apenas o **primeiro byte do digest**, usado como checksum de 4 bits na geração de palavras. Sinaliza `busy/done` para controle fácil em hardware. |
| `pbkdf_10_cycles.sv` | PBKDF2 iterativo (10 ciclos por compressão) | Prova de conceito de PBKDF2-HMAC-SHA512 para a senha e sal “mnemonic”. Usa um núcleo SHA-512 de 10 ciclos (`sha512_10cycle`) e FSM que itera 2048 vezes, acumulando `T` com XOR dos blocos U1..U2048. Inclui testbench que compara a saída com o vetor oficial. |
| `pbkdf_combinational.sv` | PBKDF2 combinacional | Versão alternativa para o mesmo caso de teste “mnemonic”, mas usando compressões SHA-512 combinacionais (um ciclo por bloco). Mantém o mesmo testbench de validação da derivação de seed. |

---

## Como as peças se encaixam

1. **Geração de frase de 12 palavras**
   - O módulo `pack_128plus4_to_12x11` (em `generate.sv`) fatia 128 bits de entropia mais 4 bits de checksum em 12 índices BIP-39.
   - `words_stream_12` sequencia esses índices para a ROM de palavras (`palavras_rom`) e retorna cada palavra como vetor de 72 bits, com `word_valid` pulsando a cada saída e `done` fixando ao final das 12 palavras.
   - O testbench `tb_words_stream_12` calcula o checksum com `sha256_firstbyte_128`, aplica a entrada e imprime a frase formatada, servindo como exemplo de integração entre SHA-256 e o gerador de palavras.

2. **Derivação PBKDF2-HMAC-SHA512**
   - Ambos os arquivos `pbkdf_10_cycles.sv` e `pbkdf_combinational.sv` implementam a derivação do seed BIP-39 padrão (senha = sal = “mnemonic” e 2048 iterações), variando apenas na arquitetura do núcleo SHA-512 (pipelining de 10 ciclos vs. bloco combinacional).
   - Cada versão inclui um testbench que inicializa `start`, espera `done` e compara `seed_out` com o vetor esperado, imprimindo PASS/FAIL na simulação.

3. **SHA-256 para checksum**
   - `sha256_firstbyte_128` processa uma mensagem de 128 bits (mais padding interno) e fornece o primeiro byte do digest. O testbench em `generate.sv` utiliza os bits [7:4] como checksum BIP-39, assegurando frases válidas.

---

## Status atual e próximos passos

- Os módulos já simulam os fluxos essenciais (geração de palavras e PBKDF2). Parte do código é experimental e pode ser reestruturada para pipelines, múltiplas instâncias em paralelo e integração com ROM de palavras completa.
- Contribuições são bem-vindas em otimização (latência × área), integração com toolflows de FPGA/ASIC e cobertura de testes.

---

## Colaboração e ética

- **Contribua tecnicamente:** Verilog/HDL, cripto aplicada, flows de síntese/implementação, validação e benchmarking.
- **Suporte opcional:** `bc1qc6yypnwtvfd09ashe73dlg5u3msr5c6xxnxxcv` (transparência sobre uso de recursos será priorizada).
- **Uso responsável:** Apenas recuperação legítima, com comprovação e consentimento. Cada caso deve começar por diagnóstico (artefatos digitais, contexto, senhas prováveis) para reduzir o espaço de busca antes de gastar energia computacional.

PRs, issues e sugestões são sempre bem-vindos! 🚀
