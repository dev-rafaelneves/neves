# Neves Finanças — MVP v2.0 (Controle Mensal Enxuto)

Aplicativo pessoal de controle financeiro mensal em **Flutter** com design **Apple Human Interface Guidelines (HIG)** e persistência **100% Local-First (SQLite)**.

## Escopo do MVP

- **Regra Única e Transparente por Mês:**
  - **Receitas do Mês:** Todas as entradas registradas no mês.
  - **Saídas à Vista (Pix / Débito):** Gastos diretos no mês, sem burocracia de conciliar saldos de múltiplas contas bancárias.
  - **Faturas de Cartão do Mês:** Compras (à vista ou parceladas) cuja fatura pertence ao mês selecionado.
  - **Quanto Sobra no Mês:** `Receitas − (Saídas à Vista + Faturas do Mês)`.
- **Lançamento Manual Ultra-Rápido (3 segundos):**
  - Campo monetário em centavos com sugestão inteligente de categoria.
  - Seleção em 1 toque entre `À Vista (Pix / Débito)` e seus `Cartões de Crédito`.
  - Sugestão automática do mês da **1ª Fatura** pelo dia de fechamento do cartão, com ajuste manual em 1 toque.
  - Suporte a parcelamento (`1x` a `24x`) com divisão exata de centavos e opção de **Repetir todo mês (Fixa)**.
- **3 Abas Diretas:**
  1. **Resumo:** Visão consolidada do mês, faturas por cartão e gastos por categoria.
  2. **Extrato:** Lista limpa com busca e filtros rápidos (`Todos`, `À Vista`, `Receitas` ou por `Cartão`).
  3. **Cartões & Ajustes:** Gestão de cartões de crédito, categorias, tema (`Sistema`, `Claro`, `Escuro`) e backup/restauração em JSON.
