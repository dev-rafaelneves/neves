# Neves Finanças — App Financeiro Pessoal (Apple HIG)

Aplicativo de gestão financeira pessoal completa construído em **Flutter**, seguindo a identidade **Apple Human Interface Guidelines (HIG)** e a arquitetura **100% Local-First** inspiradas no projeto `biostats`.

## Principais Funcionalidades

- **Design System Apple HIG**: Fundo `#F2F2F7` (modo claro) e Slate `#020617` (modo escuro), cards com raio de `14px` e bordas sutis de `0.8px`, barra inferior translúcida (`BackdropFilter`) com 4 abas e `HapticFeedback`.
- **100% Offline & Local-First**: Persistência relacional em SQLite (`sqflite`) + Backup/Restauração completa em JSON (com opção de mesclar ou substituir dados).
- **Lançamento Padrão Fluido & Importador**:
  - Modal único de lançamento com suporte a Despesas, Receitas e Transferências, status **Pago vs. Pendente**, parcelamento (`1x` a `24x`) e recorrência.
  - Importador de extratos e faturas **OFX, CSV e texto de PDF** com detecção automática de duplicatas (SHA-256) e sugestão inteligente de categoria.
- **Gestão Completa de Cartões de Crédito Brasileiros**:
  - Controle de limite total, ocupado e disponível (descontando parcelas futuras), dia de fechamento e dia de vencimento, faturas mensais e pagamento total ou parcial da fatura sem duplicar despesas.
  - **Regime Configurável**: Alterne nos Ajustes entre visão **Por Competência da Fatura** ou **Por Data da Compra**.
- **Planejamento Híbrido (Teto por Categoria + Regra 50/30/20 + Caixinhas)**:
  - Limites mensais por categoria com alertas em **80%** e **100%**.
  - Diagnóstico automático da **Regra 50/30/20** (*Essenciais*, *Estilo de Vida* e *Futuro/Reserva*).
  - **Caixinhas / Metas** com acompanhamento de progresso e aportes rápidos.
- **Patrimônio Líquido Simplificado (Net Worth)**: Contas correntes, carteira e contas de investimento somadas ao Patrimônio Líquido consolidado.
- **Consultor Financeiro IA com Google Gemini (BYOK)**: Chave armazenada com criptografia no `flutter_secure_storage` e diagnósticos mensais salvos em cache no SQLite.
- **Segurança & Privacidade**: Modo Discreto ("Olhinho"), bloqueio por PIN de 4 dígitos (SHA-256 + salt), desbloqueio biométrico (`local_auth`) e proteção `FLAG_SECURE`.
