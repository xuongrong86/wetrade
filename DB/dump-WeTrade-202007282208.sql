PGDMP     &                    x            WeTrade    12.1    12.1 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    16393    WeTrade    DATABASE     �   CREATE DATABASE "WeTrade" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'English_United States.1252' LC_CTYPE = 'English_United States.1252';
    DROP DATABASE "WeTrade";
                postgres    false            �           0    0    DATABASE "WeTrade"    COMMENT     4   COMMENT ON DATABASE "WeTrade" IS 'WeTrade Project';
                   postgres    false    2998                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                postgres    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   postgres    false    3            �            1255    16893    123(character varying)    FUNCTION     �   CREATE FUNCTION public."123"(in_clientid character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  one numeric;
  two numeric;
BEGIN
  one := 1;
  two := 2;
  RETURN one + two;
END;
$$;
 ;   DROP FUNCTION public."123"(in_clientid character varying);
       public          postgres    false    3            �            1255    17446 V   fnc_check_stock_info(character varying, character varying, character varying, integer)    FUNCTION     L
  CREATE FUNCTION public.fnc_check_stock_info(in_stocksymbol character varying, in_ordertype character varying, in_price character varying, in_quantity integer, OUT out_marketid character varying, OUT out_price numeric, OUT out_marginstockratio integer, OUT out_margincapprice numeric, OUT out_closingprice numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  13/06/2020
	-- Desc: Kiểm tra tính hợp lệ của thông tin cổ phiếu khi đặt lệnh -> kiểm tra giá, số lượng, mã cổ phiếu	
	-- Input: 	in_StockSymbol -> mã chứng khoán
	--			in_OrderType -> Loại lệnh: BUY/SELL
	--			in_Price -> giá đặt: ATO/ATC/MP/MOK/MAK/MTL ...
	--			in_Quantity -> Số lượng đặt
	-- Output: 	out_MarketID -> Sàn của mã chứng khoán
	--			out_Price -> mức giá sử dụng
	--			out_MarginStockRatio -> Tỷ lệ ký quỹ của mã chứng khoán
	--			out_ErrNum -> Mã lỗi 
DECLARE
	v_CellingPrice numeric := 0; -- giá trần
	v_FloorCelling	numeric := 0; -- giá sàn
	v_ClosingPrice	numeric := 0; -- giá tham chiếu
	v_MarketID		varchar(50) := ''; -- sàn
	v_MarginCapPrice  numeric := 0;
	v_MarginStockRatio int := 0;
	v_Price numeric := 0;
	v_StockType varchar(20);
	v_LotSize int := 0;
BEGIN
	SELECT a.EXCHG_CD, a.STOCK_TYPE, a.LOT_SIZE, a.CLOSE_PRICE, a.FLOOR_PRICE, a.CEILING_PRICE, a.MARGIN_CAP_PRICE, a.MARGIN_RATIO
		INTO v_MarketID, v_StockType, v_LotSize, v_ClosingPrice, v_FloorCelling, v_CellingPrice, v_MarginCapPrice, v_MarginStockRatio
	FROM STOCK_INFO a
	where STOCK_NO = in_StockSymbol AND STOCK_STATUS = 'N';
	
	IF NOT FOUND THEN
		out_MarketID := '';
		out_Price	:= 0;
		out_MarginStockRatio := 0;
		out_MarginCapPrice := 0;
		out_ClosingPrice := 0;
		out_ErrNum := 'STI001'; -- Mã chứng khoán không hợp lệ
		return;
	END IF;
	out_MarketID := v_MarketID;
	out_MarginStockRatio := v_MarginStockRatio;
	out_MarginCapPrice := v_MarginCapPrice;
	out_ClosingPrice := v_ClosingPrice;
	IF in_Price IN ('ATO','ATC','MP','MOK','MAK','MTL') THEN
		IF in_OrderType == 'B' THEN
			out_Price := v_CellingPrice;
		ELSE
			out_Price := v_FloorCelling;
		END IF;
	ELSE
		select to_number(in_Price,'9G999g999') INTO v_Price;
		IF (v_Price > v_CellingPrice) OR (v_Price < v_FloorCelling) THEN
			out_Price := v_Price;
			out_ErrNum := 'STI002'; -- Giá không hợp lệ
			return;
		ELSE
			out_Price := v_Price;
		END IF;
	END IF;
	
	IF MOD(in_Quantity, v_LotSize) != 0 THEN
		out_ErrNum := 'STI003'; -- Số lượng không hợp lệ
		return;	
	END IF;	
	out_ErrNum := 'STI000'; -- Hợp lệ
	return;	
END;
$$;
 [  DROP FUNCTION public.fnc_check_stock_info(in_stocksymbol character varying, in_ordertype character varying, in_price character varying, in_quantity integer, OUT out_marketid character varying, OUT out_price numeric, OUT out_marginstockratio integer, OUT out_margincapprice numeric, OUT out_closingprice numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    17041 '   fnc_get_cash_balance(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_cash_balance(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: function to get client cash balance
	-- Input: ClientID
	-- Output: return cashbalance	
DECLARE
	v_OpenCashBal numeric := 0;
	v_Cashonhold numeric := 0;
	-- v_Buyamt_Unmatch numeric := 0; -- > Mua chưa khớp đã tính trong số tiền hold
	v_CashDeposit numeric := 0;		
	v_CashBal		numeric := 0;
BEGIN
	SELECT a.opencashbal, a.cashdeposit, a.cashonhold -- , a.buyamt_unmatch
		INTO v_OpenCashBal, v_CashDeposit, v_Cashonhold -- , v_Buyamt_Unmatch
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		v_OpenCashBal := 0;
		v_CashDeposit := 0;
		v_Cashonhold := 0;
		-- v_Buyamt_Unmatch := 0;
	END IF;

	v_CashBal := v_OpenCashBal + v_CashDeposit - v_Cashonhold; -- - v_Buyamt_Unmatch;
	RETURN v_CashBal;
END; $$;
 J   DROP FUNCTION public.fnc_get_cash_balance(in_clientid character varying);
       public          postgres    false    3            �            1255    17475 "   fnc_get_fee_tax(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_fee_tax(in_productid character varying, OUT out_fee_value numeric, OUT out_tax_value numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
-- 	v_Units varchar(50); -- Đơn vị tính
-- 	v_MarketID varchar(50); -- Sàn giao dịch
-- 	v_StockType varchar(50); -- Loại chứng khoán
-- 	v_Channel varchar(50); -- Kênh giao dịch
-- 	v_MaxValue numeric; -- Chặn trên
-- 	v_MinValue numeric; -- Chặn dưới
	v_Values1 numeric; -- Giá trị
	v_Values2 numeric; -- Giá trị
BEGIN
	SELECT a.VALUES INTO out_fee_value
	FROM TEST_FEE_SETTING a
	WHERE a.FEE_ID = 'FEE_TRADE_STOCK' AND a.ACTIVE_YN = 'Y' AND a.RULES='TRADING'
		AND a.NAME_ID in (SELECT FEE_ID FROM PRODUCT_FEE WHERE PRODUCT_ID=in_ProductID);
	
	IF NOT FOUND THEN
		v_Values1 := 0.35;
	END IF;
	
	SELECT a.VALUES INTO out_tax_value
	FROM TEST_FEE_SETTING a
	WHERE a.FEE_ID = 'TAX_TRADE_STOCK' AND a.ACTIVE_YN = 'Y' AND a.RULES='TRADING'
		AND a.NAME_ID in (SELECT FEE_ID FROM PRODUCT_FEE WHERE PRODUCT_ID=in_ProductID);
		
	IF NOT FOUND THEN
		v_Values2 := 0.1;
	END IF;

	out_fee_value := v_Values1 / 100;
	out_tax_value := v_Values2 / 100;
END; $$;
 |   DROP FUNCTION public.fnc_get_fee_tax(in_productid character varying, OUT out_fee_value numeric, OUT out_tax_value numeric);
       public          postgres    false    3            �            1255    17524 �   fnc_get_fee_with_options(character varying, character varying, character varying, character varying, character varying, character varying, numeric)    FUNCTION     ,  CREATE FUNCTION public.fnc_get_fee_with_options(in_productid character varying, in_type character varying, in_option character varying, in_market character varying, in_stocktype character varying, in_channel character varying, in_value numeric, OUT out_fee_value numeric, OUT out_fee_name_id character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_Units varchar(50); -- Đơn vị tính
	v_MarketID varchar(50); -- Sàn giao dịch
	v_StockType varchar(50); -- Loại chứng khoán
	v_Channel varchar(50); -- Kênh giao dịch
	v_MaxValue numeric; -- Chặn trên
	v_MinValue numeric; -- Chặn dưới
	v_Temp_Values numeric; -- Giá trị
	v_SQL varchar;
	json_data json;
	item json;
	v_Temp_Priority int;
	v_Count int := 0;
	v_Temp_Priority1 int;
	v_Temp_Values1 numeric;
	v_Values numeric;
	
BEGIN
	v_SQL := 'SELECT json_agg(z) FROM (SELECT t."NAME_ID", t."UNITS", t."MARKETID",  t."STOCK_TYPE", t."CHANNEL", t."MAX_VALUES", t."MIN_VALUES", t."VALUES", t."PRIORITY"';
	v_SQL := v_SQL || E' FROM public."TEST_FEE_SETTING" t WHERE t."ACTIVE_YN"=''Y'' AND t."RULES" = ''' ||  in_Type || ''' AND ( ';
	
	IF (in_Market IS NOT NULL) OR (length(in_Market) > 1) THEN
		v_SQL := v_SQL || ' t."MARKETID" ='''|| in_Market || '''';
	END IF;
	
	IF (in_StockType IS NOT NULL) OR (length(in_StockType) > 1) THEN
		v_SQL := v_SQL || ' OR t."STOCK_TYPE" ='''|| in_StockType || '''';
	END IF;
	
	IF (in_Channel IS NOT NULL) OR (length(in_Channel) > 1) THEN
		v_SQL := v_SQL || ' OR t."CHANNEL" ='''|| in_Channel || '''';
	END IF;
	
	IF (in_Value IS NOT NULL) OR (in_Value > 0) THEN
		v_SQL := v_SQL || ' OR (t."MIN_VALUES" <= ' || in_Value || ' AND t."MAX_VALUES" > '|| in_Value || ')';
	END IF;
	
	v_SQL := v_SQL || '))z;';
	
	RAISE NOTICE 'Parsing %',v_SQL;
	EXECUTE v_SQL INTO json_data ;
	
	raise notice 'jsonb_array_length(js):       %', json_array_length(json_data);
	raise notice 'jsonb_DATA:       %', json_data;
	FOR item IN SELECT * FROM json_array_elements(json_data)
  	LOOP
		IF v_Count=0 THEN
			v_Temp_Priority := item ->>'PRIORITY';
			v_Temp_Values := item ->>'VALUES';
			v_Values := v_Temp_Values;
			out_FEE_NAME_ID := item ->>'NAME_ID';
		ELSE
			v_Temp_Priority1 := item ->>'PRIORITY';
			v_Temp_Values1 := item ->>'VALUES';
			IF in_Option = 'PRIORITY' THEN -- Lấy phí ưu tiên nhất (độ ưu tiên nhỏ nhất)
			RAISE NOTICE 'vO ƯU TIEN';
				IF v_Temp_Priority1	< v_Temp_Priority THEN
					v_Values := v_Temp_Values1;					
					out_FEE_NAME_ID := item ->>'NAME_ID';
				END IF;				
			END IF;	
			RAISE NOTICE 'Values0  %',v_Values;
			IF in_Option = 'VALUES' THEN -- Lấy phí nhỏ nhất
				RAISE NOTICE 'vO GIA TRI';
				IF v_Temp_Values1 < v_Temp_Values THEN
					v_Values := v_Temp_Values1;
					RAISE NOTICE 'Values  % %',v_Count, v_Values;
					out_FEE_NAME_ID := item ->>'NAME_ID';
				END IF;					
			END IF;	
			v_Temp_Priority := v_Temp_Priority1;
			v_Temp_Values := v_Temp_Values1;
		END IF;
		v_Count := v_Count+1;
	END LOOP;
	out_fee_value := v_Values;
END; $$;
 6  DROP FUNCTION public.fnc_get_fee_with_options(in_productid character varying, in_type character varying, in_option character varying, in_market character varying, in_stocktype character varying, in_channel character varying, in_value numeric, OUT out_fee_value numeric, OUT out_fee_name_id character varying);
       public          postgres    false    3            �            1255    17036 <   fnc_get_margin_dividend(character varying, numeric, numeric)    FUNCTION     w  CREATE FUNCTION public.fnc_get_margin_dividend(in_clientid character varying, in_margin_ratio numeric, in_tax_rate numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200606
	-- Desc: Lấy tiền cổ tức chờ về được tính làm tài sản đảm bảo đối với tài khoản margin
	-- Input: 	ClientID
	--			Margin ration: tỷ lệ ký quỹ (đã chia % -> ví dụ: 0.5 - 0.7 ...)
	--			Tax_Rate: phần trăm thuế TNCN phải nộp trên tiền cổ tức ( đã chia % -> ví dụ: 0.001)
	-- Output: return Margin_Dividend	
DECLARE
	v_expected_dividend numeric; -- tiền cổ tức chờ về
	v_margin_Dividend numeric; -- tiền cổ tức được tính làm tài sản đảm bảo
BEGIN
	SELECT a.expected_dividend
		INTO v_expected_dividend
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		v_expected_dividend := 0;
	END IF;

	v_margin_Dividend := v_expected_dividend * (1 - in_Tax_Rate) * in_Margin_Ratio;
	RETURN v_margin_Dividend;
END; $$;
 {   DROP FUNCTION public.fnc_get_margin_dividend(in_clientid character varying, in_margin_ratio numeric, in_tax_rate numeric);
       public          postgres    false    3            �            1255    16903 $   fnc_get_total_cia(character varying)    FUNCTION     <  CREATE FUNCTION public.fnc_get_total_cia(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: lấy tổng giá ứng trước tiền bán
	-- Input: ClientID
	-- Output: return total_margin_devidend	
	-------- = SellAmt_T + SellAmt_T1 + SellAmt_T2 - CIA_Used_T - CIA_Used_T1 - CIA_Used_T2 - PendingCIA
DECLARE
	sellAmt_T numeric; -- dự nợ đã giản ngân
	sellAmt_T1 numeric; -- lãi vay tạm tính
	sellAmt_T2 numeric; -- dư nợ dự kiến giải ngân
	CIA_Used_T numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	CIA_Used_T1 numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	CIA_Used_T2 numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	pending_CIA numeric; -- 
	total_CIA_Used numeric; ---
	total_sellAmt numeric; ---
	total_CIA_Avail numeric;
BEGIN
	SELECT a.sellamt_T, a.sellamt_T1, a.sellamt_T2, 
	a.cia_used_T, a.cia_used_T1, a.cia_used_T2, a.pending_CIA
		INTO sellAmt_T, sellAmt_T1, sellAmt_T2, CIA_Used_T, CIA_Used_T1, CIA_Used_T2, pending_CIA
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		sellAmt_T := 0;
		sellAmt_T1 := 0;
		sellAmt_T2 := 0;
		CIA_Used_T := 0;
		CIA_Used_T1 := 0;
		CIA_Used_T2 := 0;
		pending_CIA := 0;
	END IF;

	total_CIA_Used := CIA_Used_T + CIA_Used_T1 + CIA_Used_T2 + pending_CIA;
	total_sellAmt := sellAmt_T + sellAmt_T1 + sellAmt_T2 ;
	total_CIA_Avail := total_sellAmt - total_CIA_Used;
	if (total_sellAmt - total_CIA_Used) >= 0 THEN
		total_CIA_Avail := total_sellAmt - total_CIA_Used;
	ELSE
		total_CIA_Avail := 0;
	END IF;
	RETURN total_CIA_Avail;
END; $$;
 G   DROP FUNCTION public.fnc_get_total_cia(in_clientid character varying);
       public          postgres    false    3            �            1255    16900 %   fnc_get_total_loan(character varying)    FUNCTION       CREATE FUNCTION public.fnc_get_total_loan(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: lấy tổng dư nợ
	-- Input: ClientID
	-- Output: return cashbalance	
DECLARE
	debitInterest numeric; -- lãi vay tạm tính
	preLoan numeric; -- dư nợ dự kiến giải ngân		
	debitAmt numeric; -- dự nợ đã giản ngân
	othersFree numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	total_Loan numeric; -- tổng dư nợ
BEGIN
	SELECT a.debitinterest, a.pre_loan, a.debitamt, a.others_free
		INTO debitInterest, preLoan, debitAmt, othersFree
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		debitInterest := 0;
		preLoan := 0;
		debitAmt := 0;
		othersFree := 0;
	END IF;

	total_Loan := debitInterest + preLoan + debitAmt + othersFree;
	RETURN total_Loan;
END; $$;
 H   DROP FUNCTION public.fnc_get_total_loan(in_clientid character varying);
       public          postgres    false    3            �            1255    17040 .   fnc_get_total_margin_values(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_total_margin_values(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200606
	-- Desc: Lấy tổng giá trị chứng khoán được tính làm tài sản đảm bảo cho tài khoản ký quỹ
	--		Chứng khoán được tính làm tài sản đảm bảo là chứng khoán được phép giao dịch ký quỹ 
	-- Input: 	ClientID
	--			Margin ration: tỷ lệ ký quỹ (đã chia % -> ví dụ: 0.5 - 0.7 ...)
	-- Output: return total_margin_values	
DECLARE
	-- =OnHand - Sold - SellT1 - SellT2 - HoldForBlock - HoldForTemp - HoldForTrade +Dep/With + BuyT1+BuyT2+Bonus
	v_Stock_Symbol varchar(20); -- Mã chứng khoán
	v_OnHand numeric := 0; -- số lượng chứng khoán có trong tài khoản
	v_Sell numeric := 0; -- Số lượng chứng khoán bán trong ngày (khớp và chưa khớp)
	v_SellT1 numeric := 0; -- Số lượng chứng khoán khớp bán ngày T1
	v_SellT2 numeric := 0; -- Số lượng chứng khoán khớp bán ngày T2
	v_HoldForBlock numeric := 0; -- Số lượng chứng khoán tạm phong tỏa
	v_HoldForTemp numeric := 0; -- Số lượng chứng khoán bị phong tỏa
	v_HoldForTrade numeric := 0; -- SLCP chờ giao dịch. ???
	v_Dep_With numeric := 0; -- Số lượng chứng khoán nộp/rút
	v_BuyT1 numeric := 0; -- Số lượng chứng khoán mua ngày T1
	v_BuyT2 numeric := 0; -- Số lượng chứng khoán mua ngày T2
	v_Bonus numeric := 0; -- Số lượng cổ phiếu thưởng, cổ tức bằng cổ phiếu ...
	v_Margin_Price numeric := 0; -- Giá margin
	v_Margin_Stock_Ratio numeric := 0; -- Tỷ lệ ký quỹ của cổ phiếu
	v_Quantity numeric  := 0; -- Số lượng cổ phiếu tính làm TSDB
	v_Total_Margin_Value numeric  := 0; --
	v_Temp_Value numeric := 0; 
	rec_portfolio   RECORD;
	curs_portfolio CURSOR (t_ClientID varchar) FOR
		SELECT a.stock_symbol, a.on_hand, a.sell_t, a.sell_t1, a.sell_t2,
		a.hold_for_block, a.hold_for_temp, a.hold_for_trade, a.dep_with, a.bonus, a.buy_t1, a.buy_t2	
	FROM client_stock_bal a
	WHERE a.clientid = t_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_stock_bal b where b.clientid = t_ClientID);
BEGIN
	OPEN curs_portfolio(in_ClientID);
	LOOP
		-- fetch row into the film
		FETCH curs_portfolio INTO rec_portfolio;
		-- exit when no more row to fetch
		EXIT WHEN NOT FOUND;
		v_Stock_Symbol := rec_portfolio.stock_symbol;
		v_OnHand := rec_portfolio.on_hand;
		v_Sell := rec_portfolio.sell_t;
		v_SellT1 := rec_portfolio.sell_t1;
		v_SellT2 := rec_portfolio.sell_t2;
		v_HoldForBlock := rec_portfolio.hold_for_block;
		v_HoldForTemp := rec_portfolio.hold_for_temp;
		v_HoldForTrade := rec_portfolio.hold_for_trade;
		v_Bonus := rec_portfolio.bonus;
		v_Dep_With := rec_portfolio.dep_with;
		v_BuyT1 := rec_portfolio.buy_t1;
		v_BuyT2 := rec_portfolio.buy_t2;
		v_Quantity = v_OnHand - v_Sell - v_SellT1 - v_SellT2- v_HoldForBlock - v_HoldForTemp - v_HoldForTrade + v_Dep_With + v_BuyT1 + v_BuyT2 + v_Bonus;

		SELECT LEAST(s.MARGIN_CAP_PRICE, s.CLOSE_PRICE) as margin_price,  s.MARGIN_RATIO 
			INTO v_Margin_Price, v_Margin_Stock_Ratio
		FROM STOCK_INFO s 
		where s.STOCK_NO = v_Stock_Symbol;
		
		IF NOT FOUND THEN
			v_Margin_Price := 0;
			v_Margin_Stock_Ratio := 1;
		END IF;
		v_Temp_Value := v_Quantity * v_Margin_Price * v_Margin_Stock_Ratio;

		v_Total_Margin_Value := v_Total_Margin_Value + v_Temp_Value;	
	END LOOP;

   -- Close the cursor
	CLOSE curs_portfolio;	

	RETURN v_Total_Margin_Value;
END; $$;
 Q   DROP FUNCTION public.fnc_get_total_margin_values(in_clientid character varying);
       public          postgres    false    3            �            1255    17413 D   fnc_get_trading_power(character varying, numeric, character varying)    FUNCTION     b  CREATE FUNCTION public.fnc_get_trading_power(in_clientid character varying, in_margin_ratio numeric, in_stock_symbol character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Tính sức mua
	-- Input: ClientID
	--			Margin Ratio
	--			Stock Symbol
	-- Output: return cashbalance	
DECLARE
	v_Total_Loan numeric := 0; -- Tổng dư nợ
	v_Margin_Dividend numeric := 0; -- Tiền cổ tức chờ về		
	v_Total_CIA numeric := 0; -- Ứng trước tiền bán
	v_Total_Margin_Market_Values numeric := 0; -- Tổng giá trị chứng khoán ký quỹ
	v_Cash_Balance numeric := 0; -- Tổng số dư tiền mặt
	v_Available_Balance numeric := 0; -- Số dư tiền
	v_Stock_Margin_Ratio numeric :=0; -- Tỷ lệ ký quỹ của cổ phiếu muốn mua
	v_Trading_Power numeric := 0; -- Sức mua
BEGIN
	SELECT s.MARGIN_RATIO 
			INTO v_Stock_Margin_Ratio
		FROM STOCK_INFO s 
		where s.STOCK_NO = in_Stock_Symbol;
	
	IF NOT FOUND THEN
		v_Stock_Margin_Ratio := 1;
	END IF;
	SELECT fnc_get_total_margin_values(in_ClientID) INTO v_Total_Margin_Market_Values;
	SELECT fnc_get_total_loan(in_ClientID) INTO v_Total_Loan;
	SELECT fnc_get_total_cia(in_ClientID) INTO v_Total_CIA;
	SELECT fnc_get_margin_dividend(in_ClientID) INTO v_Margin_Dividend;
	SELECT fnc_get_cash_balance(in_ClientID) INTO v_Cash_Balance;
	
	v_Available_Balance := v_Cash_Balance - v_Total_Loan + v_Total_CIA + v_Margin_Dividend;
	
	v_Trading_Power = ( v_Available_Balance + v_Total_Margin_Market_Values * in_Margin_Ratio) / (1 - in_Margin_Ratio * v_Stock_Margin_Ratio);
	
	RETURN v_Trading_Power;
END; $$;
 �   DROP FUNCTION public.fnc_get_trading_power(in_clientid character varying, in_margin_ratio numeric, in_stock_symbol character varying);
       public          postgres    false    3            �            1255    17544 3   fucn_check_account_info(character varying, numeric)    FUNCTION     �  CREATE FUNCTION public.fucn_check_account_info(in_clientid character varying, in_marginratio numeric, OUT out_productid character varying, OUT out_marginlimit numeric, OUT out_errnum character varying, OUT out_branchno integer, OUT out_brokerid character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Kiểm tra thông tin tài khoản của khách hàng
	-- Input: 	in_ClientID -> mã khách hàng
	--			in_MarginRatio -> Tỷ lệ ký quỹ sử dụng (nếu tài khoản bankGW = 0)
	-- Output: 	out_ErrNum -> Mã lỗi ACC0000 -> Thành công
DECLARE
	v_ProDuctID varchar(50); -- Loại tài khoản của khách hàng
	v_BranchNo int := 0;
	v_BrokerID varchar(50);
	v_MarginRatio numeric := 0;
	v_MarginLimit numeric := 0;
BEGIN
	-- Lấy thông tin loại tài khoản của khách hàng
	SELECT "ACCT_TYPE", "BRANCH_NO", "BROKER_ID" INTO v_ProDuctID, v_BranchNo, v_BrokerID
	FROM public."CUSTOMER_INFO" t WHERE t."ACCT_STATUS"='ACTIVE' AND t."CUST_ID" = in_ClientID;
	
	IF NOT FOUND THEN
		out_ErrNum := 'ACC0001'; -- Account không tồn tại
		return;
	END IF;

	-- Check tỷ lệ ký quỹ ứng 
	SELECT z."MARGIN_RATIO", z."MARGIN_LIMIT"
		INTO v_MarginRatio, v_MarginLimit
	FROM public."MARGIN_SETTING" z 
	where z."ACTIVE_YN"='Y' AND z."MARGIN_RATIO" = in_MarginRatio
		AND EXISTS (SELECT 1 FROM public."PRODUCT_SETTING" a WHERE a."ACTIVE_YN"='Y' AND a."MARGIN_ID"=z."MARGIN_ID" AND a."PRODUCT_ID" = v_ProDuctID);
		
	IF NOT FOUND THEN
		out_ErrNum := 'ACC0002'; -- Tỷ lệ ký quỹ không hợp lệ
		return;
	END IF;
	out_ProductID := v_ProDuctID;
	out_MarginLimit := v_MarginLimit;
	out_BranchNo := v_BranchNo;
	out_BrokerID := v_BrokerID;
	out_ErrNum := 'ACC000';
END; $$;
   DROP FUNCTION public.fucn_check_account_info(in_clientid character varying, in_marginratio numeric, OUT out_productid character varying, OUT out_marginlimit numeric, OUT out_errnum character varying, OUT out_branchno integer, OUT out_brokerid character varying);
       public          postgres    false    3            �            1255    17542 �   func_add_order(character varying, character varying, character varying, character varying, character varying, numeric, character varying, numeric, integer, character varying, character varying, numeric, date)    FUNCTION     �  CREATE FUNCTION public.func_add_order(in_clientid character varying, in_marketid character varying, in_channel character varying, in_stocksymbol character varying, in_price character varying, in_quantity numeric, in_ordertype character varying, in_totalvalue numeric, in_branchno integer, in_tradeid character varying, in_brokerid character varying, in_feepct numeric, in_tradedate date, OUT out_sysorder numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_ErrNum varchar(20); -- Đơn vị tính
	v_SysOrderNo bigint; 
	v_OrderStatus varchar(20) := 'RS'; --
	v_DMAFlag character := 'Y';
	v_MarketID varchar(50);
	v_Price numeric;
	v_MarginStockRatio integer;
	v_MarginCapPrice numeric;
	v_ClosingPrice numeric;
	v_Tax numeric;
	v_Fee numeric;
	v_TotalValue numeric;
	v_OrderValue numeric;
	v_FeeValue numeric;
	v_TaxValue numeric;
	v_TradingPower numeric;
BEGIN
	SELECT nextval('ORDER_SQ') INTO v_SysOrderNo;
	INSERT INTO public."ORDER"(
		"SYS_ORDER_NO", "EXCHG_CD", "CHANNEL", "ORDER_STATUS", "STOCK_CD", "ORDER_PRICE", "ORDER_QTY", "BID_ASK_TYPE", 
		"BRANCH_NO", "EXCHG_ORDER_TYPE", "CUST_ID",  "PARENT_ORDER_NO", "TRADE_ID", "BROKER_ID", 
		"DMA_FLAG",  "FREE_PCT", "LAST_UPD_DT", "TRADE_DATE")
	VALUES(v_SysOrderNo, in_MarketID, in_Channel, v_OrderStatus, in_StockSymbol, in_Price, in_Quantity, in_OrderType,
		  in_BranchNo, in_OrderType, in_ClientID, 0, in_TradeID, in_BrokerID, v_DMAFlag, in_FeePCT, CURRENT_TIMESTAMP, in_TradeDate);

	IF in_OrderType = 'B' THEN
		insert into	public.client_stock_bal( clientid,
											tradedate,
											marketid,
											stock_symbol,
											buy_t,
											update_time)
		values(in_ClientID, 
			   in_TradeDate, 
			   in_MarketID, 
			   in_StockSymbol, 
			   in_Quantity, 
			   CURRENT_TIMESTAMP)
		ON CONFLICT (clientid, tradedate, marketid, stock_symbol) 
		DO
			UPDATE 
			SET buy_t = in_Quantity
			WHERE  clientid = in_ClientID AND tradedate = in_TradeDate and marketid=in_MarketID AND stock_symbol=in_StockSymbol;
		-- CẬP NHẬT LẠI SỐ DƯ TIỀN
		update public."client_cash_bal"
		set	cashonhold =in_TotalValue,	buyamt_unmatch = in_TotalValue,	update_time = CURRENT_TIMESTAMP
		where clientid = in_ClientID AND tradedate = in_TradeDate;
	END IF;
	
	IF in_OrderType = 'S' THEN
		-- Giảm số lượng chứng khoán có thể mua
		UPDATE public."client_stock_bal"
		SET sellable = sellable - in_Quantity
		WHERE  clientid = in_ClientID AND tradedate = in_TradeDate and marketid=in_MarketID AND stock_symbol=in_StockSymbol;
	END IF;
	out_ErrNum := 'ODR000'; -- THÀNH CÔNG
	COMMIT;
EXCEPTION
   WHEN OTHERS THEN
   out_ErrNum := SQLERRM || SQLSTATE;
   ROLLBACK;
END; $$;
 �  DROP FUNCTION public.func_add_order(in_clientid character varying, in_marketid character varying, in_channel character varying, in_stocksymbol character varying, in_price character varying, in_quantity numeric, in_ordertype character varying, in_totalvalue numeric, in_branchno integer, in_tradeid character varying, in_brokerid character varying, in_feepct numeric, in_tradedate date, OUT out_sysorder numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    17545 �   func_execute_order(character varying, character varying, character varying, character varying, numeric, character varying, numeric)    FUNCTION       CREATE FUNCTION public.func_execute_order(in_clientid character varying, in_channel character varying, in_ordertype character varying, in_stocksymbol character varying, in_quantity numeric, in_price character varying, in_marginratio numeric, OUT out_sysorder numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_ErrNum varchar(20); -- Đơn vị tính
	v_ProDuctID varchar(50); -- Loại tài khoản của khách hàng
	v_BranchNo int := 0;
	v_BrokerID varchar(50);
	v_MarginLimit numeric := 0; --
	v_MarketID varchar(50);
	v_Price numeric;
	v_MarginStockRatio integer;
	v_MarginCapPrice numeric;
	v_ClosingPrice numeric;
	v_Tax numeric;
	v_Fee numeric;
	v_TotalValue numeric;
	v_OrderValue numeric;
	v_FeeValue numeric;
	v_TaxValue numeric;
	v_TradingPower numeric;
	v_Sellable numeric := 0;
	v_SysOrderNo numeric := 0;
BEGIN
	-- Kiểm tra thông tin khách hàng, nếu không hợp lệ thì báo lỗi
	SELECT * FROM fucn_check_account_info(in_ClientID,in_MarginRatio) INTO v_ProDuctID, v_MarginLimit, v_ErrNum, v_BranchNo, v_BrokerID;	
	IF v_ErrNum <> 'ACC000' THEN
		out_ErrNum := v_ErrNum;
		return;
	END IF;
	
	-- Kiểm tra thông tin lệnh đặt (bước giá, số lượng đặt )
	SELECT * FROM fnc_check_stock_info(in_StockSymbol, in_OrderType, in_Price, in_Quantity) 
		INTO v_MarketID, v_Price, v_MarginStockRatio, v_MarginCapPrice, v_ClosingPrice, v_ErrNum;
	IF v_ErrNum <> 'STI000' THEN
		out_ErrNum := v_ErrNum;
		return;
	END IF;
	
	-- Lấy giá trị thuế, phí giao dịch
	SELECT * FROM fnc_get_fee_tax(v_ProDuctID) INTO v_Fee, v_Tax;
	
	v_OrderValue := in_Quantity * v_Price;
	v_FeeValue := v_TotalValue * v_Fee;
	-- Xử lý lệnh mua
	IF in_OrderType = 'B' THEN
		-- Lấy sức mua
		SELECT fnc_get_trading_power(in_ClientID, in_MarginRatio, in_StockSymbol) INTO v_TradingPower;
		v_TotalValue := v_OrderValue + v_FeeValue;
		
		IF v_TotalValue > v_TradingPower THEN
			out_ErrNum := 'ODR001'; -- không đủ sức mua
			return;
		END IF;
	END IF;
	
	IF in_OrderType = 'S' THEN
		SELECT sellable INTO v_Sellable
		FROM public.client_stock_bal
		WHERE clientid = in_ClientID AND tradedate = CURRENT_DATE AND stock_symbol=in_StockSymbol;
		
		IF NOT FOUND THEN
			out_ErrNum := 'ODR002'; -- mã chứng khoán không có trong danh mục
			return;
		END IF;
		
		IF in_Quantity > v_Sellable THEN
			out_ErrNum := 'ODR003'; -- Số lượng đặt quá số lượng chứng khoán sở hữu
			return;
		END IF;		
	END IF;
	
	SELECT * FROM func_add_order(in_ClientID, v_MarketID, in_Channel, in_StockSymbol, v_Price, in_Quantity, in_OrderType, v_TotalValue, v_BranchNo, in_ClientID, v_BrokerID, v_Fee, CURRENT_DATE)
	INTO out_SysOrder, out_ErrNum;
END; $$;
 -  DROP FUNCTION public.func_execute_order(in_clientid character varying, in_channel character varying, in_ordertype character varying, in_stocksymbol character varying, in_quantity numeric, in_price character varying, in_marginratio numeric, OUT out_sysorder numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    16885    get_sum(numeric, numeric)    FUNCTION       CREATE FUNCTION public.get_sum(a numeric, b numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: function to get client cash balance
	-- Input: ClientID
	-- Output: return cashbalance	
BEGIN
	RETURN a + b;
END; $$;
 4   DROP FUNCTION public.get_sum(a numeric, b numeric);
       public          postgres    false    3            �            1255    17533     hi_lo(numeric, numeric, numeric)    FUNCTION     �   CREATE FUNCTION public.hi_lo(a numeric, b numeric, c numeric, OUT hi numeric, OUT lo numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
	hi := GREATEST(a,b,c);
	lo := LEAST(a,b,c);
END; $$;
 ]   DROP FUNCTION public.hi_lo(a numeric, b numeric, c numeric, OUT hi numeric, OUT lo numeric);
       public          postgres    false    3            �            1255    17443    sum_n_product(integer, integer)    FUNCTION     �   CREATE FUNCTION public.sum_n_product(x integer, y integer, OUT sum integer, OUT prod numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF x = 0 THEN
		sum := 0;
		prod := 0;
		return;
	END IF;
    sum := x + y;
    prod := x * y;
END;
$$;
 ]   DROP FUNCTION public.sum_n_product(x integer, y integer, OUT sum integer, OUT prod numeric);
       public          postgres    false    3            �            1259    17090    CUSTOMER_INFO    TABLE     �  CREATE TABLE public."CUSTOMER_INFO" (
    "CUST_ID" character varying(50) NOT NULL,
    "CUST_NAME" character varying(100) NOT NULL,
    "TAX_ID" character varying(20),
    "ID_ISSUE_DATE" date,
    "ID_ISSUE_PLACE" character varying(20),
    "ID_TYPE" character(1),
    "BIRTH_DATE" date,
    "SEX" character varying(20),
    "MOBILE_PHONE" character varying(20),
    "FAX_NO" character varying(20),
    "ADDRESS_1" text,
    "ADDRESS_2" text,
    "NATIONALITY" character varying(20),
    "CUST_TYPE" character(1),
    "ACCT_TYPE" character varying(20),
    "BANK_ACCT" character varying(20),
    "BRANCH_NO" integer,
    "ACCT_STATUS" character varying(20),
    "BROKER_ID" character varying(20),
    "OPEN_DATE" timestamp without time zone,
    "CLOSE_DATE" timestamp without time zone,
    "UPD_DATE" timestamp without time zone,
    "OPEN_UID" character varying(20),
    "CLOSE_UID" character varying(20),
    "UPD_UID" character varying(20)
);
 #   DROP TABLE public."CUSTOMER_INFO";
       public         heap    postgres    false    3            �           0    0     COLUMN "CUSTOMER_INFO"."CUST_ID"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CUST_NAME"    COMMENT     M   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_NAME" IS 'Tên khách hàng';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."TAX_ID"    COMMENT     M   COMMENT ON COLUMN public."CUSTOMER_INFO"."TAX_ID" IS 'Số CMND / Passport';
          public          postgres    false    206            �           0    0 &   COLUMN "CUSTOMER_INFO"."ID_ISSUE_DATE"    COMMENT     Y   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_ISSUE_DATE" IS 'Ngày cấp CMND/Passport';
          public          postgres    false    206            �           0    0 '   COLUMN "CUSTOMER_INFO"."ID_ISSUE_PLACE"    COMMENT     Y   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_ISSUE_PLACE" IS 'Nơi cấp CMND/Passport';
          public          postgres    false    206            �           0    0     COLUMN "CUSTOMER_INFO"."ID_TYPE"    COMMENT     W   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_TYPE" IS 'Loại: 0: CMND - 1: Passport';
          public          postgres    false    206            �           0    0 #   COLUMN "CUSTOMER_INFO"."BIRTH_DATE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."BIRTH_DATE" IS 'Ngày tháng năm sinh';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."SEX"    COMMENT     B   COMMENT ON COLUMN public."CUSTOMER_INFO"."SEX" IS 'Giới tính';
          public          postgres    false    206            �           0    0 %   COLUMN "CUSTOMER_INFO"."MOBILE_PHONE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."MOBILE_PHONE" IS 'Số điện thoại';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."FAX_NO"    COMMENT     A   COMMENT ON COLUMN public."CUSTOMER_INFO"."FAX_NO" IS 'Số Fax';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ADDRESS_1"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."ADDRESS_1" IS 'Địa chỉ 1';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ADDRESS_2"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."ADDRESS_2" IS 'Địa chỉ 2';
          public          postgres    false    206            �           0    0 $   COLUMN "CUSTOMER_INFO"."NATIONALITY"    COMMENT     K   COMMENT ON COLUMN public."CUSTOMER_INFO"."NATIONALITY" IS 'Quốc tịch';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CUST_TYPE"    COMMENT     p   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_TYPE" IS 'Loại Khách hàng -> P: Cá nhân - O: Tổ chức';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ACCT_TYPE"    COMMENT     l   COMMENT ON COLUMN public."CUSTOMER_INFO"."ACCT_TYPE" IS 'Loại tài khoản: bank hay margin hay VIP ...';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BANK_ACCT"    COMMENT     O   COMMENT ON COLUMN public."CUSTOMER_INFO"."BANK_ACCT" IS 'Tài khoản tiền';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BRANCH_NO"    COMMENT     F   COMMENT ON COLUMN public."CUSTOMER_INFO"."BRANCH_NO" IS 'Chi nhánh';
          public          postgres    false    206            �           0    0 $   COLUMN "CUSTOMER_INFO"."ACCT_STATUS"    COMMENT     m   COMMENT ON COLUMN public."CUSTOMER_INFO"."ACCT_STATUS" IS 'Trạng thái tài khoản: active/close/Freeze';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BROKER_ID"    COMMENT     E   COMMENT ON COLUMN public."CUSTOMER_INFO"."BROKER_ID" IS 'Broker ID';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."OPEN_DATE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."OPEN_DATE" IS 'Ngày mở tài khoản';
          public          postgres    false    206            �           0    0 #   COLUMN "CUSTOMER_INFO"."CLOSE_DATE"    COMMENT     V   COMMENT ON COLUMN public."CUSTOMER_INFO"."CLOSE_DATE" IS 'Ngày đóng tài khoản';
          public          postgres    false    206            �           0    0 !   COLUMN "CUSTOMER_INFO"."UPD_DATE"    COMMENT     Z   COMMENT ON COLUMN public."CUSTOMER_INFO"."UPD_DATE" IS 'Ngày cập nhật gần nhất';
          public          postgres    false    206            �           0    0 !   COLUMN "CUSTOMER_INFO"."OPEN_UID"    COMMENT     Q   COMMENT ON COLUMN public."CUSTOMER_INFO"."OPEN_UID" IS 'User mở tài khoản';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CLOSE_UID"    COMMENT     T   COMMENT ON COLUMN public."CUSTOMER_INFO"."CLOSE_UID" IS 'User đóng tài khoản';
          public          postgres    false    206            �           0    0     COLUMN "CUSTOMER_INFO"."UPD_UID"    COMMENT     k   COMMENT ON COLUMN public."CUSTOMER_INFO"."UPD_UID" IS 'User cập nhật tài khoản lần gần nhất';
          public          postgres    false    206            �            1259    16922    FEE_CATEGORY    TABLE       CREATE TABLE public."FEE_CATEGORY" (
    "FEE_ID" character varying(50) NOT NULL,
    "DESC_EN" text,
    "DESC_VN" text,
    "EFFECTIVE_DATE" date,
    "TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "LAST_UPDATED" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."FEE_CATEGORY";
       public         heap    postgres    false    3            �           0    0    COLUMN "FEE_CATEGORY"."FEE_ID"    COMMENT     l   COMMENT ON COLUMN public."FEE_CATEGORY"."FEE_ID" IS 'Mã phí giao dịch - số tự động tăng dần';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."DESC_EN"    COMMENT     R   COMMENT ON COLUMN public."FEE_CATEGORY"."DESC_EN" IS 'Diễn giải tiếng anh';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."DESC_VN"    COMMENT     U   COMMENT ON COLUMN public."FEE_CATEGORY"."DESC_VN" IS 'Diễn giải tiếng việt';
          public          postgres    false    204            �           0    0 &   COLUMN "FEE_CATEGORY"."EFFECTIVE_DATE"    COMMENT     P   COMMENT ON COLUMN public."FEE_CATEGORY"."EFFECTIVE_DATE" IS 'Ngày áp dụng';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."TYPE"    COMMENT     ^   COMMENT ON COLUMN public."FEE_CATEGORY"."TYPE" IS 'Loại phí: phần trăm, cố định)';
          public          postgres    false    204            �           0    0 !   COLUMN "FEE_CATEGORY"."ACTIVE_YN"    COMMENT     ^   COMMENT ON COLUMN public."FEE_CATEGORY"."ACTIVE_YN" IS 'Phí còn áp dụng hay không Y/N';
          public          postgres    false    204            �           0    0 $   COLUMN "FEE_CATEGORY"."LAST_UPDATED"    COMMENT     c   COMMENT ON COLUMN public."FEE_CATEGORY"."LAST_UPDATED" IS 'Thời gian cập nhật cuối cùng';
          public          postgres    false    204            �            1259    17139    FEE_LIST    TABLE     \  CREATE TABLE public."FEE_LIST" (
    "FEE_ID" character varying(50) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "FEE_TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public."FEE_LIST";
       public         heap    postgres    false    3            �           0    0    TABLE "FEE_LIST"    COMMENT     E   COMMENT ON TABLE public."FEE_LIST" IS 'Danh sách các loại phí';
          public          postgres    false    209            �            1259    17365    FEE_SETTING    TABLE     �  CREATE TABLE public."FEE_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "MARKETID" character varying(50),
    "STOCK_TYPE" character varying(50),
    "CHANNEL" character varying(50),
    "MAX_VALUES" numeric(20,0),
    "MIN_VALUES" numeric(20,0),
    "VALUES" numeric(20,4),
    "ACTIVE_YN" "char",
    "RULES" character varying(50),
    "FEE_ID" character varying(50)
);
 !   DROP TABLE public."FEE_SETTING";
       public         heap    postgres    false    3            �            1259    17153 	   LOAN_LIST    TABLE     _  CREATE TABLE public."LOAN_LIST" (
    "LOAN_ID" character varying(50) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "LOAN_TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public."LOAN_LIST";
       public         heap    postgres    false    3            �            1259    17161    LOAN_SETTING    TABLE     %  CREATE TABLE public."LOAN_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "INTEREST_RATE" integer,
    "ACTIVE_YN" "char",
    "LOAN_TERM" integer,
    "DIVISOR" integer,
    "LOAN_ID" character varying(50)
);
 "   DROP TABLE public."LOAN_SETTING";
       public         heap    postgres    false    3            �            1259    17164    MARGIN_SETTING    TABLE     �  CREATE TABLE public."MARGIN_SETTING" (
    "MARGIN_ID" character varying(20) NOT NULL,
    "MARGIN_DESC" character varying(200),
    "MARGIN_RATIO" numeric(20,0) DEFAULT 0,
    "MARGIN_LIMIT" numeric(20,0) DEFAULT 0,
    "MARGIN_CALL_RATE" numeric(20,0) DEFAULT 0,
    "MARGIN_FORCE_RATE" numeric(20,0) DEFAULT 0,
    "ACTIVE_YN" "char" DEFAULT 'Y'::"char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 $   DROP TABLE public."MARGIN_SETTING";
       public         heap    postgres    false    3            �            1259    17414    ORDER    TABLE     �  CREATE TABLE public."ORDER" (
    "SYS_ORDER_NO" bigint NOT NULL,
    "EXCHG_CD" character varying(20),
    "CHANNEL" character varying(10),
    "ORDER_STATUS" character varying(10),
    "STOCK_CD" character varying(20),
    "ORDER_PRICE" integer,
    "ORDER_QTY" integer,
    "EXEC_QTY" integer,
    "BID_ASK_TYPE" character varying(10),
    "ORDER_SUBMIT_DT" timestamp with time zone,
    "BRANCH_NO" integer,
    "EXCHG_ORDER_TYPE" character varying(10),
    "CUST_ID" character varying(50),
    "SHORTSELL_FLG" character(1),
    "PARENT_ORDER_NO" bigint,
    "TRADE_ID" character varying(50),
    "BROKER_ID" character varying(50),
    "EXCHG_SUBMIT_DT" timestamp with time zone,
    "GOOD_TILL_DATE" date,
    "HOLD_STATUS" character varying(10),
    "DMA_FLAG" character(1),
    "PRIORITY_FLG" character(1),
    "FREE_PCT" integer,
    "LAST_UPD_DT" timestamp with time zone,
    "TRADE_DATE" date
);
    DROP TABLE public."ORDER";
       public         heap    postgres    false    3            �           0    0    COLUMN "ORDER"."SYS_ORDER_NO"    COMMENT     N   COMMENT ON COLUMN public."ORDER"."SYS_ORDER_NO" IS 'Số thứ tự lệnh ';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."EXCHG_CD"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."EXCHG_CD" IS 'Sàn giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."CHANNEL"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."CHANNEL" IS 'Kênh giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_STATUS"    COMMENT     K   COMMENT ON COLUMN public."ORDER"."ORDER_STATUS" IS 'Trạng thái lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."STOCK_CD"    COMMENT     E   COMMENT ON COLUMN public."ORDER"."STOCK_CD" IS 'Mã chứng khoán';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_PRICE"    COMMENT     A   COMMENT ON COLUMN public."ORDER"."ORDER_PRICE" IS 'Gía đặt';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_QTY"    COMMENT     J   COMMENT ON COLUMN public."ORDER"."ORDER_QTY" IS 'Khối lượng đặt';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."EXEC_QTY"    COMMENT     H   COMMENT ON COLUMN public."ORDER"."EXEC_QTY" IS 'Khối lương khớp';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BID_ASK_TYPE"    COMMENT     N   COMMENT ON COLUMN public."ORDER"."BID_ASK_TYPE" IS 'Loại lệnh: Mua/bán';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."ORDER_SUBMIT_DT"    COMMENT     S   COMMENT ON COLUMN public."ORDER"."ORDER_SUBMIT_DT" IS 'Thời gian đặt lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BRANCH_NO"    COMMENT     >   COMMENT ON COLUMN public."ORDER"."BRANCH_NO" IS 'Chi nhánh';
          public          postgres    false    217            �           0    0 !   COLUMN "ORDER"."EXCHG_ORDER_TYPE"    COMMENT     j   COMMENT ON COLUMN public."ORDER"."EXCHG_ORDER_TYPE" IS 'Loại lệnh trên sàn: ATO/ATC/LO/MP/MAK/MOK';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."CUST_ID"    COMMENT     B   COMMENT ON COLUMN public."ORDER"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."SHORTSELL_FLG"    COMMENT     T   COMMENT ON COLUMN public."ORDER"."SHORTSELL_FLG" IS 'Lệnh bị shortsell -> Y/N';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."PARENT_ORDER_NO"    COMMENT     D   COMMENT ON COLUMN public."ORDER"."PARENT_ORDER_NO" IS 'Lệnh cha';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."TRADE_ID"    COMMENT     L   COMMENT ON COLUMN public."ORDER"."TRADE_ID" IS 'Nhân viên đặt lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BROKER_ID"    COMMENT     J   COMMENT ON COLUMN public."ORDER"."BROKER_ID" IS 'Môi giới quản lý';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."EXCHG_SUBMIT_DT"    COMMENT     O   COMMENT ON COLUMN public."ORDER"."EXCHG_SUBMIT_DT" IS 'Thời gian lên sàn';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."GOOD_TILL_DATE"    COMMENT     m   COMMENT ON COLUMN public."ORDER"."GOOD_TILL_DATE" IS 'Ngày giao dịch - Dùng cho đặt lệnh trước';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."HOLD_STATUS"    COMMENT     g   COMMENT ON COLUMN public."ORDER"."HOLD_STATUS" IS 'Tình trạng phong tỏa tiền bên ngân hàng';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."DMA_FLAG"    COMMENT     [   COMMENT ON COLUMN public."ORDER"."DMA_FLAG" IS 'Cờ DMA: giao dịch online hay offline';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."PRIORITY_FLG"    COMMENT     G   COMMENT ON COLUMN public."ORDER"."PRIORITY_FLG" IS 'Lệnh ưu tiên';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."FREE_PCT"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."FREE_PCT" IS 'Phí giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."LAST_UPD_DT"    COMMENT     [   COMMENT ON COLUMN public."ORDER"."LAST_UPD_DT" IS 'Thời gian cập nhật cuối cùng';
          public          postgres    false    217            �            1259    17419    ORDER_DETAIL    TABLE     e  CREATE TABLE public."ORDER_DETAIL" (
    "SYS_ORDER_NO" bigint NOT NULL,
    "ORDER_SUB_NO" integer NOT NULL,
    "EXCHG_CD" character varying(20),
    "TRADE_DATE" date,
    "SESSION_ID" integer,
    "ORDER_QTY" integer,
    "ORDER_PRICE" integer,
    "STATUS" character varying(20),
    "CREATE_DATE" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."ORDER_DETAIL";
       public         heap    postgres    false    3            �           0    0 $   COLUMN "ORDER_DETAIL"."SYS_ORDER_NO"    COMMENT     o   COMMENT ON COLUMN public."ORDER_DETAIL"."SYS_ORDER_NO" IS 'Số thứ tự lệnh-> ứng với bảng ORDER';
          public          postgres    false    218            �           0    0 $   COLUMN "ORDER_DETAIL"."ORDER_SUB_NO"    COMMENT     �   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_SUB_NO" IS 'Số thứ tự con của từng lệnh: bắt đầu từ 1 đến n đối với từng lệnh';
          public          postgres    false    218            �           0    0     COLUMN "ORDER_DETAIL"."EXCHG_CD"    COMMENT     J   COMMENT ON COLUMN public."ORDER_DETAIL"."EXCHG_CD" IS 'Sàn giao dịch';
          public          postgres    false    218            �           0    0 "   COLUMN "ORDER_DETAIL"."TRADE_DATE"    COMMENT     M   COMMENT ON COLUMN public."ORDER_DETAIL"."TRADE_DATE" IS 'Ngày giao dịch';
          public          postgres    false    218            �           0    0 "   COLUMN "ORDER_DETAIL"."SESSION_ID"    COMMENT     N   COMMENT ON COLUMN public."ORDER_DETAIL"."SESSION_ID" IS 'Phiên giao dịch';
          public          postgres    false    218            �           0    0 !   COLUMN "ORDER_DETAIL"."ORDER_QTY"    COMMENT     J   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_QTY" IS 'Khối lượng';
          public          postgres    false    218            �           0    0 #   COLUMN "ORDER_DETAIL"."ORDER_PRICE"    COMMENT     A   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_PRICE" IS 'Giá';
          public          postgres    false    218            �           0    0    COLUMN "ORDER_DETAIL"."STATUS"    COMMENT     L   COMMENT ON COLUMN public."ORDER_DETAIL"."STATUS" IS 'Trạng thái lệnh';
          public          postgres    false    218            �           0    0 #   COLUMN "ORDER_DETAIL"."CREATE_DATE"    COMMENT     Z   COMMENT ON COLUMN public."ORDER_DETAIL"."CREATE_DATE" IS 'Thời gian tạo dữ liệu';
          public          postgres    false    218            �            1259    17534    ORDER_SQ    SEQUENCE     r   CREATE SEQUENCE public."ORDER_SQ"
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE public."ORDER_SQ";
       public          postgres    false    3            �            1259    17396    PRODUCT_FEE    TABLE     7  CREATE TABLE public."PRODUCT_FEE" (
    "PRODUCT_ID" character varying(50) NOT NULL,
    "FEE_ID" character varying(200) NOT NULL,
    "ACTIVE_YN" "char",
    "EFFECT_DATE" date,
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 !   DROP TABLE public."PRODUCT_FEE";
       public         heap    postgres    false    3            �            1259    17180    PRODUCT_LIST    TABLE     V  CREATE TABLE public."PRODUCT_LIST" (
    "PRODUCT_ID" character varying(20) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "ACTIVE_YN" "char",
    "EFFECT_DATE" date,
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."PRODUCT_LIST";
       public         heap    postgres    false    3            �            1259    17185    PRODUCT_SETTING    TABLE     9  CREATE TABLE public."PRODUCT_SETTING" (
    "PRODUCT_ID" character varying(20) NOT NULL,
    "MARGIN_ID" character varying(20) NOT NULL,
    "ACTIVE_YN" "char" DEFAULT 'Y'::"char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 %   DROP TABLE public."PRODUCT_SETTING";
       public         heap    postgres    false    3            �            1259    16476 
   STOCK_INFO    TABLE     o  CREATE TABLE public."STOCK_INFO" (
    "EXCHG_CD" character varying(50)[] NOT NULL,
    "STOCK_NO" character varying(50)[] NOT NULL,
    "STOCK_TYPE" character varying(50)[],
    "STOCK_STATUS" character varying(200)[],
    "STOCK_NAME" character varying(200)[],
    "STOCK_NAMEEN" character varying(200)[],
    "LOT_SIZE" integer,
    "START_TRADE_DT" date,
    "END_TRADE_DT" date,
    "CLOSE_PRICE" numeric,
    "LAST_CLOSE_PRICE" numeric,
    "FLOOR_PRICE" numeric,
    "CEILING_PRICE" numeric,
    "TOTAL_ROOM" numeric,
    "CURRENT_ROOM" numeric,
    "OFFICAL_CODE" character varying(20)[],
    "ISSUED_SHARE" numeric,
    "LISTED_SHARE" numeric,
    "MARGIN_CAP_PRICE" numeric,
    "ISIN_CODE" character varying(20)[],
    "SEDOL_CODE" character varying(20)[],
    "UPD_SRC" character varying(20)[],
    "UPD_DT" timestamp without time zone,
    "MARGIN_RATIO" integer
);
     DROP TABLE public."STOCK_INFO";
       public         heap    postgres    false    3            �           0    0    COLUMN "STOCK_INFO"."EXCHG_CD"    COMMENT     K   COMMENT ON COLUMN public."STOCK_INFO"."EXCHG_CD" IS 'Sàn chứng khoán';
          public          postgres    false    202            �           0    0    COLUMN "STOCK_INFO"."STOCK_NO"    COMMENT     J   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NO" IS 'Mã chứng khoán';
          public          postgres    false    202            �           0    0     COLUMN "STOCK_INFO"."STOCK_TYPE"    COMMENT     v   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_TYPE" IS 'Loại: chứng khoán, chứng chỉ quỹ, phái sinh ... ';
          public          postgres    false    202            �           0    0 "   COLUMN "STOCK_INFO"."STOCK_STATUS"    COMMENT     �   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_STATUS" IS 'Trạng thái chứng khoán: bình thường, hạn chế giao dịch, hủy niêm yết ...';
          public          postgres    false    202            �           0    0     COLUMN "STOCK_INFO"."STOCK_NAME"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NAME" IS 'Tên tiếng việt của chứng khoán';
          public          postgres    false    202                        0    0 "   COLUMN "STOCK_INFO"."STOCK_NAMEEN"    COMMENT     L   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NAMEEN" IS 'Tên tiếng anh';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."LOT_SIZE"    COMMENT     w   COMMENT ON COLUMN public."STOCK_INFO"."LOT_SIZE" IS 'Khối lượng đặt tối thiểu: HSX: 10cp, HNX\UPCOM: 100';
          public          postgres    false    202                       0    0 $   COLUMN "STOCK_INFO"."START_TRADE_DT"    COMMENT     \   COMMENT ON COLUMN public."STOCK_INFO"."START_TRADE_DT" IS 'Ngày giao dịch đầu tiên';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."END_TRADE_DT"    COMMENT     Z   COMMENT ON COLUMN public."STOCK_INFO"."END_TRADE_DT" IS 'Ngày giao dịch cuối cùng';
          public          postgres    false    202                       0    0 !   COLUMN "STOCK_INFO"."CLOSE_PRICE"    COMMENT     U   COMMENT ON COLUMN public."STOCK_INFO"."CLOSE_PRICE" IS 'Giá đóng cửa hôm nay';
          public          postgres    false    202                       0    0 &   COLUMN "STOCK_INFO"."LAST_CLOSE_PRICE"    COMMENT     _   COMMENT ON COLUMN public."STOCK_INFO"."LAST_CLOSE_PRICE" IS 'Giá đóng cửa hôm trước';
          public          postgres    false    202                       0    0 !   COLUMN "STOCK_INFO"."FLOOR_PRICE"    COMMENT     D   COMMENT ON COLUMN public."STOCK_INFO"."FLOOR_PRICE" IS 'Giá sàn';
          public          postgres    false    202                       0    0 #   COLUMN "STOCK_INFO"."CEILING_PRICE"    COMMENT     H   COMMENT ON COLUMN public."STOCK_INFO"."CEILING_PRICE" IS 'Giá trần';
          public          postgres    false    202                       0    0     COLUMN "STOCK_INFO"."TOTAL_ROOM"    COMMENT     T   COMMENT ON COLUMN public."STOCK_INFO"."TOTAL_ROOM" IS 'Tổng room nước ngoài';
          public          postgres    false    202            	           0    0 "   COLUMN "STOCK_INFO"."CURRENT_ROOM"    COMMENT     Z   COMMENT ON COLUMN public."STOCK_INFO"."CURRENT_ROOM" IS 'Room nước ngoài còn lại';
          public          postgres    false    202            
           0    0 "   COLUMN "STOCK_INFO"."OFFICAL_CODE"    COMMENT     X   COMMENT ON COLUMN public."STOCK_INFO"."OFFICAL_CODE" IS 'ID chứng khoán của sở';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."ISSUED_SHARE"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."ISSUED_SHARE" IS 'Số lượng cổ phiếu phát hành';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."LISTED_SHARE"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."LISTED_SHARE" IS 'Số lượng cổ phiếu niêm yết';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."ISIN_CODE"    COMMENT     A   COMMENT ON COLUMN public."STOCK_INFO"."ISIN_CODE" IS 'Mã ISIN';
          public          postgres    false    202                       0    0     COLUMN "STOCK_INFO"."SEDOL_CODE"    COMMENT     C   COMMENT ON COLUMN public."STOCK_INFO"."SEDOL_CODE" IS 'Mã SEDOL';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."UPD_SRC"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."UPD_SRC" IS 'Nguồn cập nhật thông tin dữ liệu';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."UPD_DT"    COMMENT     ^   COMMENT ON COLUMN public."STOCK_INFO"."UPD_DT" IS 'Thời gian cập thông tin dữ liệu';
          public          postgres    false    202            �            1259    17454    TEST_FEE_SETTING    TABLE       CREATE TABLE public."TEST_FEE_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "MARKETID" character varying(50),
    "STOCK_TYPE" character varying(50),
    "CHANNEL" character varying(50),
    "MAX_VALUES" numeric(20,0),
    "MIN_VALUES" numeric(20,0),
    "VALUES" numeric(20,4),
    "ACTIVE_YN" "char",
    "TYPE" character varying(50),
    "FEE_ID" character varying(50),
    "PRIORITY" integer,
    "RULES" character varying(50)
);
 &   DROP TABLE public."TEST_FEE_SETTING";
       public         heap    postgres    false    3            �            1259    17099 	   USER_AUTH    TABLE       CREATE TABLE public."USER_AUTH" (
    "LOGIN_UID" character varying(50) NOT NULL,
    "CHANNEL" character varying(20) NOT NULL,
    "CUST_ID" character varying(50) NOT NULL,
    "LOGIN_PWD" character varying(200),
    "TRADE_PWD" character varying(200),
    "LOGIN_RETRY" integer,
    "LAST_LOGIN_DT" timestamp without time zone,
    "LATEST_LOGIN_DT" timestamp without time zone
);
    DROP TABLE public."USER_AUTH";
       public         heap    postgres    false    3                       0    0    COLUMN "USER_AUTH"."LOGIN_UID"    COMMENT     J   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_UID" IS 'Tên đăng nhập';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."CHANNEL"    COMMENT     U   COMMENT ON COLUMN public."USER_AUTH"."CHANNEL" IS 'Kênh đăng nhập: Mobile/Web';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."CUST_ID"    COMMENT     F   COMMENT ON COLUMN public."USER_AUTH"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."LOGIN_PWD"    COMMENT     R   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_PWD" IS 'Mật khẩu đăng nhập';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."TRADE_PWD"    COMMENT     L   COMMENT ON COLUMN public."USER_AUTH"."TRADE_PWD" IS 'Mật khẩu trading';
          public          postgres    false    207                       0    0     COLUMN "USER_AUTH"."LOGIN_RETRY"    COMMENT     W   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_RETRY" IS 'Số lần đăng nhập fail';
          public          postgres    false    207                       0    0 "   COLUMN "USER_AUTH"."LAST_LOGIN_DT"    COMMENT     b   COMMENT ON COLUMN public."USER_AUTH"."LAST_LOGIN_DT" IS 'Thời gian đăng nhập gần nhất';
          public          postgres    false    207                       0    0 $   COLUMN "USER_AUTH"."LATEST_LOGIN_DT"    COMMENT     d   COMMENT ON COLUMN public."USER_AUTH"."LATEST_LOGIN_DT" IS 'Thời gian đăng nhập lần cuối';
          public          postgres    false    207            �            1259    17130    client_cash_bal    TABLE     �  CREATE TABLE public.client_cash_bal (
    clientid character varying(50) NOT NULL,
    tradedate date NOT NULL,
    opencashbal numeric,
    cashdeposit numeric,
    cashonhold numeric,
    buyamt_unmatch numeric,
    sellamt_unmatch numeric,
    sellamt_t1 numeric,
    sellamt_t2 numeric,
    buyamt_t1 numeric,
    buyamt_t2 numeric,
    buyamt_t numeric,
    sellamt_t numeric,
    debitinterest numeric,
    credit_interest numeric,
    others_free numeric,
    cia_used_t numeric,
    cia_used_t1 numeric,
    cia_used_t2 numeric,
    pending_cia numeric,
    debitamt numeric,
    pre_loan numeric,
    expected_dividend numeric,
    margin_dividend numeric,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 #   DROP TABLE public.client_cash_bal;
       public         heap    postgres    false    3                       0    0     COLUMN client_cash_bal.tradedate    COMMENT     K   COMMENT ON COLUMN public.client_cash_bal.tradedate IS 'Ngày làm việc';
          public          postgres    false    208                       0    0 "   COLUMN client_cash_bal.opencashbal    COMMENT     Q   COMMENT ON COLUMN public.client_cash_bal.opencashbal IS 'Số dư đầu ngày';
          public          postgres    false    208                       0    0 "   COLUMN client_cash_bal.cashdeposit    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.cashdeposit IS 'Số tiền nộp vào';
          public          postgres    false    208                       0    0 !   COLUMN client_cash_bal.cashonhold    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.cashonhold IS 'Số tiền phong tỏa';
          public          postgres    false    208                       0    0 %   COLUMN client_cash_bal.buyamt_unmatch    COMMENT     o   COMMENT ON COLUMN public.client_cash_bal.buyamt_unmatch IS 'Lệnh mua trong ngày chưa khớp (gồm phí)';
          public          postgres    false    208                       0    0 &   COLUMN client_cash_bal.sellamt_unmatch    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.sellamt_unmatch IS 'Lệnh bán trong ngày chưa khớp (đã trừ thuế, phí GD)';
          public          postgres    false    208                       0    0 !   COLUMN client_cash_bal.sellamt_t1    COMMENT     x   COMMENT ON COLUMN public.client_cash_bal.sellamt_t1 IS 'Giá trị bán khớp ngày T+1 (đã trừ thuế, phí GD)';
          public          postgres    false    208                        0    0 !   COLUMN client_cash_bal.sellamt_t2    COMMENT     x   COMMENT ON COLUMN public.client_cash_bal.sellamt_t2 IS 'Giá trị bán khớp ngày T+2 (đã trừ thuế, phí GD)';
          public          postgres    false    208            !           0    0     COLUMN client_cash_bal.buyamt_t1    COMMENT     f   COMMENT ON COLUMN public.client_cash_bal.buyamt_t1 IS 'Giá trị mua khớp ngày T+1 (gồm phí)';
          public          postgres    false    208            "           0    0     COLUMN client_cash_bal.buyamt_t2    COMMENT     f   COMMENT ON COLUMN public.client_cash_bal.buyamt_t2 IS 'Giá trị mua khớp ngày T+2 (gồm phí)';
          public          postgres    false    208            #           0    0    COLUMN client_cash_bal.buyamt_t    COMMENT     g   COMMENT ON COLUMN public.client_cash_bal.buyamt_t IS 'Giá trị mua khớp trong ngày (gồm phí)';
          public          postgres    false    208            $           0    0     COLUMN client_cash_bal.sellamt_t    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.sellamt_t IS 'Giá trị bán khớp trong ngày (đã trừ thuế, phí giao dịch)';
          public          postgres    false    208            %           0    0 $   COLUMN client_cash_bal.debitinterest    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.debitinterest IS 'Lãi vay tạm tính';
          public          postgres    false    208            &           0    0 &   COLUMN client_cash_bal.credit_interest    COMMENT     Z   COMMENT ON COLUMN public.client_cash_bal.credit_interest IS 'Lãi tiền gởi dự thu';
          public          postgres    false    208            '           0    0 "   COLUMN client_cash_bal.others_free    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.others_free IS 'Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …';
          public          postgres    false    208            (           0    0 !   COLUMN client_cash_bal.cia_used_t    COMMENT     [   COMMENT ON COLUMN public.client_cash_bal.cia_used_t IS 'Tiền ứng sử dụng ngày T';
          public          postgres    false    208            )           0    0 "   COLUMN client_cash_bal.cia_used_t1    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.cia_used_t1 IS 'Tiền ứng sử dụng ngày T-1';
          public          postgres    false    208            *           0    0 "   COLUMN client_cash_bal.cia_used_t2    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.cia_used_t2 IS 'Tiền ứng sử dụng ngày T-2';
          public          postgres    false    208            +           0    0 "   COLUMN client_cash_bal.pending_cia    COMMENT     \   COMMENT ON COLUMN public.client_cash_bal.pending_cia IS 'Tiền ứng đang chờ duyệt';
          public          postgres    false    208            ,           0    0    COLUMN client_cash_bal.debitamt    COMMENT     S   COMMENT ON COLUMN public.client_cash_bal.debitamt IS 'Dư nợ đã giải ngân';
          public          postgres    false    208            -           0    0    COLUMN client_cash_bal.pre_loan    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.pre_loan IS 'Dư nợ dự kiến giải ngân - từ deal mua chưa đến hạn thành toán';
          public          postgres    false    208            .           0    0 (   COLUMN client_cash_bal.expected_dividend    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.expected_dividend IS 'Tiền cổ tức chờ về';
          public          postgres    false    208            /           0    0 &   COLUMN client_cash_bal.margin_dividend    COMMENT     }   COMMENT ON COLUMN public.client_cash_bal.margin_dividend IS 'Tiền cổ tức được tính làm tài sản đảm bảo';
          public          postgres    false    208            �            1259    16870    client_stock_bal    TABLE     M  CREATE TABLE public.client_stock_bal (
    clientid character varying(50) NOT NULL,
    tradedate date NOT NULL,
    marketid character varying(20),
    stock_symbol character varying(20),
    sellable integer,
    buy_t integer,
    bought_t integer,
    sell_t integer,
    sold_t integer,
    buy_t1 integer,
    sell_t1 integer,
    buy_t2 integer,
    sell_t2 integer,
    hold_for_block integer,
    hold_for_temp integer,
    hold_for_trade integer,
    dep_with integer,
    on_hand integer,
    bonus integer,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 $   DROP TABLE public.client_stock_bal;
       public         heap    postgres    false    3            0           0    0     COLUMN client_stock_bal.marketid    COMMENT     J   COMMENT ON COLUMN public.client_stock_bal.marketid IS 'Sàn giao dịch';
          public          postgres    false    203            1           0    0 $   COLUMN client_stock_bal.stock_symbol    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.stock_symbol IS 'Mã chứng khoán';
          public          postgres    false    203            2           0    0     COLUMN client_stock_bal.sellable    COMMENT     c   COMMENT ON COLUMN public.client_stock_bal.sellable IS 'Số lượng cổ phiếu có thể bán';
          public          postgres    false    203            3           0    0    COLUMN client_stock_bal.buy_t    COMMENT     ~   COMMENT ON COLUMN public.client_stock_bal.buy_t IS 'Số lượng cổ phiếu đặt mua trong ngày (khớp/chưa khớp)';
          public          postgres    false    203            4           0    0     COLUMN client_stock_bal.bought_t    COMMENT     U   COMMENT ON COLUMN public.client_stock_bal.bought_t IS 'SLCP Khớp mua trong ngày';
          public          postgres    false    203            5           0    0    COLUMN client_stock_bal.sell_t    COMMENT     j   COMMENT ON COLUMN public.client_stock_bal.sell_t IS 'SLCP đặt bán trong ngày (Khớp/Chưa khớp)';
          public          postgres    false    203            6           0    0    COLUMN client_stock_bal.sold_t    COMMENT     S   COMMENT ON COLUMN public.client_stock_bal.sold_t IS 'SLCP Khớp mua trong ngày';
          public          postgres    false    203            7           0    0    COLUMN client_stock_bal.buy_t1    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.buy_t1 IS 'SLCP Khớp mua ngày T1';
          public          postgres    false    203            8           0    0    COLUMN client_stock_bal.sell_t1    COMMENT     R   COMMENT ON COLUMN public.client_stock_bal.sell_t1 IS 'SLCP Khớp bán ngày T1';
          public          postgres    false    203            9           0    0    COLUMN client_stock_bal.buy_t2    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.buy_t2 IS 'SLCP Khớp mua ngày T2';
          public          postgres    false    203            :           0    0    COLUMN client_stock_bal.sell_t2    COMMENT     R   COMMENT ON COLUMN public.client_stock_bal.sell_t2 IS 'SLCP Khớp bán ngày T2';
          public          postgres    false    203            ;           0    0 &   COLUMN client_stock_bal.hold_for_block    COMMENT     V   COMMENT ON COLUMN public.client_stock_bal.hold_for_block IS 'SLCP tạm phong tỏa';
          public          postgres    false    203            <           0    0 %   COLUMN client_stock_bal.hold_for_temp    COMMENT        COMMENT ON COLUMN public.client_stock_bal.hold_for_temp IS 'SLCP phong tỏa (Ví dụ: hạn chế chuyển nhượng, …)';
          public          postgres    false    203            =           0    0 &   COLUMN client_stock_bal.hold_for_trade    COMMENT     W   COMMENT ON COLUMN public.client_stock_bal.hold_for_trade IS 'SLCP chờ giao dịch.';
          public          postgres    false    203            >           0    0     COLUMN client_stock_bal.dep_with    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.dep_with IS 'SLCP Nộp (nhận chuyển khoản) trong ngày
SLCP Rút (chuyển khoản) trong ngày nếu là số âm';
          public          postgres    false    203            ?           0    0    COLUMN client_stock_bal.on_hand    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.on_hand IS 'SLCP đang có trong tài khoản.
 Gồm tất cả các loại cp (kể cả cp BÁN chờ thanh toán), ngoại
 trừ: cp MUA chờ nhận thanh toán, cp Quyền chưa lưu ký
 (Bonus)';
          public          postgres    false    203            @           0    0    COLUMN client_stock_bal.bonus    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.bonus IS 'Cp thưởng, Cổ tức bằng cp, Quyền mua đã đăng ký …chưa lưu ký.';
          public          postgres    false    203            �            1259    16931    interest_category    TABLE     5  CREATE TABLE public.interest_category (
    id character varying(50) NOT NULL,
    desc_vn character varying(200),
    desc_en character varying(200),
    effective_date date,
    "TYPE" character varying(50),
    active_yn character(1),
    last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 %   DROP TABLE public.interest_category;
       public         heap    postgres    false    3            �          0    17090    CUSTOMER_INFO 
   TABLE DATA           l  COPY public."CUSTOMER_INFO" ("CUST_ID", "CUST_NAME", "TAX_ID", "ID_ISSUE_DATE", "ID_ISSUE_PLACE", "ID_TYPE", "BIRTH_DATE", "SEX", "MOBILE_PHONE", "FAX_NO", "ADDRESS_1", "ADDRESS_2", "NATIONALITY", "CUST_TYPE", "ACCT_TYPE", "BANK_ACCT", "BRANCH_NO", "ACCT_STATUS", "BROKER_ID", "OPEN_DATE", "CLOSE_DATE", "UPD_DATE", "OPEN_UID", "CLOSE_UID", "UPD_UID") FROM stdin;
    public          postgres    false    206            �          0    16922    FEE_CATEGORY 
   TABLE DATA              COPY public."FEE_CATEGORY" ("FEE_ID", "DESC_EN", "DESC_VN", "EFFECTIVE_DATE", "TYPE", "ACTIVE_YN", "LAST_UPDATED") FROM stdin;
    public          postgres    false    204            �          0    17139    FEE_LIST 
   TABLE DATA           {   COPY public."FEE_LIST" ("FEE_ID", "DESC_VN", "DESC_EN", "FEE_TYPE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    209            �          0    17365    FEE_SETTING 
   TABLE DATA           �   COPY public."FEE_SETTING" ("NAME_ID", "DESC", "UNITS", "MARKETID", "STOCK_TYPE", "CHANNEL", "MAX_VALUES", "MIN_VALUES", "VALUES", "ACTIVE_YN", "RULES", "FEE_ID") FROM stdin;
    public          postgres    false    215            �          0    17153 	   LOAN_LIST 
   TABLE DATA           ~   COPY public."LOAN_LIST" ("LOAN_ID", "DESC_VN", "DESC_EN", "LOAN_TYPE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    210            �          0    17161    LOAN_SETTING 
   TABLE DATA           �   COPY public."LOAN_SETTING" ("NAME_ID", "DESC", "UNITS", "INTEREST_RATE", "ACTIVE_YN", "LOAN_TERM", "DIVISOR", "LOAN_ID") FROM stdin;
    public          postgres    false    211            �          0    17164    MARGIN_SETTING 
   TABLE DATA           �   COPY public."MARGIN_SETTING" ("MARGIN_ID", "MARGIN_DESC", "MARGIN_RATIO", "MARGIN_LIMIT", "MARGIN_CALL_RATE", "MARGIN_FORCE_RATE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    212            �          0    17414    ORDER 
   TABLE DATA           �  COPY public."ORDER" ("SYS_ORDER_NO", "EXCHG_CD", "CHANNEL", "ORDER_STATUS", "STOCK_CD", "ORDER_PRICE", "ORDER_QTY", "EXEC_QTY", "BID_ASK_TYPE", "ORDER_SUBMIT_DT", "BRANCH_NO", "EXCHG_ORDER_TYPE", "CUST_ID", "SHORTSELL_FLG", "PARENT_ORDER_NO", "TRADE_ID", "BROKER_ID", "EXCHG_SUBMIT_DT", "GOOD_TILL_DATE", "HOLD_STATUS", "DMA_FLAG", "PRIORITY_FLG", "FREE_PCT", "LAST_UPD_DT", "TRADE_DATE") FROM stdin;
    public          postgres    false    217            �          0    17419    ORDER_DETAIL 
   TABLE DATA           �   COPY public."ORDER_DETAIL" ("SYS_ORDER_NO", "ORDER_SUB_NO", "EXCHG_CD", "TRADE_DATE", "SESSION_ID", "ORDER_QTY", "ORDER_PRICE", "STATUS", "CREATE_DATE") FROM stdin;
    public          postgres    false    218            �          0    17396    PRODUCT_FEE 
   TABLE DATA           y   COPY public."PRODUCT_FEE" ("PRODUCT_ID", "FEE_ID", "ACTIVE_YN", "EFFECT_DATE", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    216            �          0    17180    PRODUCT_LIST 
   TABLE DATA           �   COPY public."PRODUCT_LIST" ("PRODUCT_ID", "DESC_VN", "DESC_EN", "ACTIVE_YN", "EFFECT_DATE", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    213            �          0    17185    PRODUCT_SETTING 
   TABLE DATA           q   COPY public."PRODUCT_SETTING" ("PRODUCT_ID", "MARGIN_ID", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    214            �          0    16476 
   STOCK_INFO 
   TABLE DATA           �  COPY public."STOCK_INFO" ("EXCHG_CD", "STOCK_NO", "STOCK_TYPE", "STOCK_STATUS", "STOCK_NAME", "STOCK_NAMEEN", "LOT_SIZE", "START_TRADE_DT", "END_TRADE_DT", "CLOSE_PRICE", "LAST_CLOSE_PRICE", "FLOOR_PRICE", "CEILING_PRICE", "TOTAL_ROOM", "CURRENT_ROOM", "OFFICAL_CODE", "ISSUED_SHARE", "LISTED_SHARE", "MARGIN_CAP_PRICE", "ISIN_CODE", "SEDOL_CODE", "UPD_SRC", "UPD_DT", "MARGIN_RATIO") FROM stdin;
    public          postgres    false    202            �          0    17454    TEST_FEE_SETTING 
   TABLE DATA           �   COPY public."TEST_FEE_SETTING" ("NAME_ID", "DESC", "UNITS", "MARKETID", "STOCK_TYPE", "CHANNEL", "MAX_VALUES", "MIN_VALUES", "VALUES", "ACTIVE_YN", "TYPE", "FEE_ID", "PRIORITY", "RULES") FROM stdin;
    public          postgres    false    219            �          0    17099 	   USER_AUTH 
   TABLE DATA           �   COPY public."USER_AUTH" ("LOGIN_UID", "CHANNEL", "CUST_ID", "LOGIN_PWD", "TRADE_PWD", "LOGIN_RETRY", "LAST_LOGIN_DT", "LATEST_LOGIN_DT") FROM stdin;
    public          postgres    false    207            �          0    17130    client_cash_bal 
   TABLE DATA           m  COPY public.client_cash_bal (clientid, tradedate, opencashbal, cashdeposit, cashonhold, buyamt_unmatch, sellamt_unmatch, sellamt_t1, sellamt_t2, buyamt_t1, buyamt_t2, buyamt_t, sellamt_t, debitinterest, credit_interest, others_free, cia_used_t, cia_used_t1, cia_used_t2, pending_cia, debitamt, pre_loan, expected_dividend, margin_dividend, update_time) FROM stdin;
    public          postgres    false    208            �          0    16870    client_stock_bal 
   TABLE DATA           �   COPY public.client_stock_bal (clientid, tradedate, marketid, stock_symbol, sellable, buy_t, bought_t, sell_t, sold_t, buy_t1, sell_t1, buy_t2, sell_t2, hold_for_block, hold_for_temp, hold_for_trade, dep_with, on_hand, bonus, update_time) FROM stdin;
    public          postgres    false    203            �          0    16931    interest_category 
   TABLE DATA           r   COPY public.interest_category (id, desc_vn, desc_en, effective_date, "TYPE", active_yn, last_updated) FROM stdin;
    public          postgres    false    205            A           0    0    ORDER_SQ    SEQUENCE SET     9   SELECT pg_catalog.setval('public."ORDER_SQ"', 1, false);
          public          postgres    false    220            �
           2606    17097    CUSTOMER_INFO CLIENT_INFO_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public."CUSTOMER_INFO"
    ADD CONSTRAINT "CLIENT_INFO_pkey" PRIMARY KEY ("CUST_ID");
 L   ALTER TABLE ONLY public."CUSTOMER_INFO" DROP CONSTRAINT "CLIENT_INFO_pkey";
       public            postgres    false    206                       2606    17278    FEE_LIST FEE_LIST_PKEY 
   CONSTRAINT     ^   ALTER TABLE ONLY public."FEE_LIST"
    ADD CONSTRAINT "FEE_LIST_PKEY" PRIMARY KEY ("FEE_ID");
 D   ALTER TABLE ONLY public."FEE_LIST" DROP CONSTRAINT "FEE_LIST_PKEY";
       public            postgres    false    209                       2606    17372    FEE_SETTING FEE_SETTING1_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public."FEE_SETTING"
    ADD CONSTRAINT "FEE_SETTING1_pkey" PRIMARY KEY ("NAME_ID");
 K   ALTER TABLE ONLY public."FEE_SETTING" DROP CONSTRAINT "FEE_SETTING1_pkey";
       public            postgres    false    215            �
           2606    16950    FEE_CATEGORY FEE_SETTING_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY public."FEE_CATEGORY"
    ADD CONSTRAINT "FEE_SETTING_pkey" PRIMARY KEY ("FEE_ID");
 K   ALTER TABLE ONLY public."FEE_CATEGORY" DROP CONSTRAINT "FEE_SETTING_pkey";
       public            postgres    false    204                       2606    17266    LOAN_LIST LOAN_LIST_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public."LOAN_LIST"
    ADD CONSTRAINT "LOAN_LIST_pkey" PRIMARY KEY ("LOAN_ID");
 F   ALTER TABLE ONLY public."LOAN_LIST" DROP CONSTRAINT "LOAN_LIST_pkey";
       public            postgres    false    210                       2606    17268    LOAN_SETTING LOAN_SETTING_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public."LOAN_SETTING"
    ADD CONSTRAINT "LOAN_SETTING_pkey" PRIMARY KEY ("NAME_ID");
 L   ALTER TABLE ONLY public."LOAN_SETTING" DROP CONSTRAINT "LOAN_SETTING_pkey";
       public            postgres    false    211            	           2606    17270 "   MARGIN_SETTING MARGIN_SETTING_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public."MARGIN_SETTING"
    ADD CONSTRAINT "MARGIN_SETTING_pkey" PRIMARY KEY ("MARGIN_ID");
 P   ALTER TABLE ONLY public."MARGIN_SETTING" DROP CONSTRAINT "MARGIN_SETTING_pkey";
       public            postgres    false    212                       2606    17423    ORDER_DETAIL ORDER_DETAIL_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public."ORDER_DETAIL"
    ADD CONSTRAINT "ORDER_DETAIL_pkey" PRIMARY KEY ("SYS_ORDER_NO", "ORDER_SUB_NO");
 L   ALTER TABLE ONLY public."ORDER_DETAIL" DROP CONSTRAINT "ORDER_DETAIL_pkey";
       public            postgres    false    218    218                       2606    17418    ORDER ORDER_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public."ORDER"
    ADD CONSTRAINT "ORDER_pkey" PRIMARY KEY ("SYS_ORDER_NO");
 >   ALTER TABLE ONLY public."ORDER" DROP CONSTRAINT "ORDER_pkey";
       public            postgres    false    217                       2606    17402    PRODUCT_FEE PRODUCT_FEE1_pkey 
   CONSTRAINT     s   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_pkey" PRIMARY KEY ("PRODUCT_ID", "FEE_ID");
 K   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_pkey";
       public            postgres    false    216    216                       2606    17274    PRODUCT_LIST PRODUCT_LIST_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public."PRODUCT_LIST"
    ADD CONSTRAINT "PRODUCT_LIST_pkey" PRIMARY KEY ("PRODUCT_ID");
 L   ALTER TABLE ONLY public."PRODUCT_LIST" DROP CONSTRAINT "PRODUCT_LIST_pkey";
       public            postgres    false    213                       2606    17276 $   PRODUCT_SETTING PRODUCT_SETTING_pkey 
   CONSTRAINT     }   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_pkey" PRIMARY KEY ("PRODUCT_ID", "MARGIN_ID");
 R   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_pkey";
       public            postgres    false    214    214            �
           2606    17549    STOCK_INFO STOCK_INFO_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public."STOCK_INFO"
    ADD CONSTRAINT "STOCK_INFO_pkey" PRIMARY KEY ("STOCK_NO", "EXCHG_CD");
 H   ALTER TABLE ONLY public."STOCK_INFO" DROP CONSTRAINT "STOCK_INFO_pkey";
       public            postgres    false    202    202                       2606    17461 '   TEST_FEE_SETTING TEST_FEE_SETTING1_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public."TEST_FEE_SETTING"
    ADD CONSTRAINT "TEST_FEE_SETTING1_pkey" PRIMARY KEY ("NAME_ID");
 U   ALTER TABLE ONLY public."TEST_FEE_SETTING" DROP CONSTRAINT "TEST_FEE_SETTING1_pkey";
       public            postgres    false    219            �
           2606    17106    USER_AUTH USER_AUTH_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public."USER_AUTH"
    ADD CONSTRAINT "USER_AUTH_pkey" PRIMARY KEY ("LOGIN_UID", "CUST_ID");
 F   ALTER TABLE ONLY public."USER_AUTH" DROP CONSTRAINT "USER_AUTH_pkey";
       public            postgres    false    207    207                       2606    17138 "   client_cash_bal client_cash_bal_pk 
   CONSTRAINT     q   ALTER TABLE ONLY public.client_cash_bal
    ADD CONSTRAINT client_cash_bal_pk PRIMARY KEY (clientid, tradedate);
 L   ALTER TABLE ONLY public.client_cash_bal DROP CONSTRAINT client_cash_bal_pk;
       public            postgres    false    208    208            �
           2606    16875 $   client_stock_bal client_stock_bal_pk 
   CONSTRAINT     s   ALTER TABLE ONLY public.client_stock_bal
    ADD CONSTRAINT client_stock_bal_pk PRIMARY KEY (clientid, tradedate);
 N   ALTER TABLE ONLY public.client_stock_bal DROP CONSTRAINT client_stock_bal_pk;
       public            postgres    false    203    203            �
           2606    16938 &   interest_category interest_category_pk 
   CONSTRAINT     d   ALTER TABLE ONLY public.interest_category
    ADD CONSTRAINT interest_category_pk PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.interest_category DROP CONSTRAINT interest_category_pk;
       public            postgres    false    205                       2606    17373 &   FEE_SETTING FEE_SETTING1_fkey_FEE_LIST    FK CONSTRAINT     �   ALTER TABLE ONLY public."FEE_SETTING"
    ADD CONSTRAINT "FEE_SETTING1_fkey_FEE_LIST" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_LIST"("FEE_ID");
 T   ALTER TABLE ONLY public."FEE_SETTING" DROP CONSTRAINT "FEE_SETTING1_fkey_FEE_LIST";
       public          postgres    false    209    2819    215                       2606    17403 $   PRODUCT_FEE PRODUCT_FEE1_FEE_ID_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_FEE_ID_fkey" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_SETTING"("NAME_ID");
 R   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_FEE_ID_fkey";
       public          postgres    false    2831    215    216                       2606    17408 (   PRODUCT_FEE PRODUCT_FEE1_PRODUCT_ID_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_PRODUCT_ID_fkey" FOREIGN KEY ("PRODUCT_ID") REFERENCES public."PRODUCT_LIST"("PRODUCT_ID");
 V   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_PRODUCT_ID_fkey";
       public          postgres    false    2827    216    213                       2606    17295 3   PRODUCT_SETTING PRODUCT_SETTING_MARGIN_SETTING_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_MARGIN_SETTING_fkey" FOREIGN KEY ("MARGIN_ID") REFERENCES public."MARGIN_SETTING"("MARGIN_ID");
 a   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_MARGIN_SETTING_fkey";
       public          postgres    false    214    2825    212                       2606    17300 1   PRODUCT_SETTING PRODUCT_SETTING_PRODUCT_LIST_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_PRODUCT_LIST_fkey" FOREIGN KEY ("PRODUCT_ID") REFERENCES public."PRODUCT_LIST"("PRODUCT_ID");
 _   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_PRODUCT_LIST_fkey";
       public          postgres    false    214    2827    213                       2606    17462 0   TEST_FEE_SETTING TEST_FEE_SETTING1_fkey_FEE_LIST    FK CONSTRAINT     �   ALTER TABLE ONLY public."TEST_FEE_SETTING"
    ADD CONSTRAINT "TEST_FEE_SETTING1_fkey_FEE_LIST" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_LIST"("FEE_ID");
 ^   ALTER TABLE ONLY public."TEST_FEE_SETTING" DROP CONSTRAINT "TEST_FEE_SETTING1_fkey_FEE_LIST";
       public          postgres    false    2819    219    209                       2606    17425    ORDER_DETAIL order_detail_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ORDER_DETAIL"
    ADD CONSTRAINT order_detail_fk FOREIGN KEY ("SYS_ORDER_NO") REFERENCES public."ORDER"("SYS_ORDER_NO");
 H   ALTER TABLE ONLY public."ORDER_DETAIL" DROP CONSTRAINT order_detail_fk;
       public          postgres    false    218    217    2835                       2606    17107 &   USER_AUTH user_auth_fkey_customer_info    FK CONSTRAINT     �   ALTER TABLE ONLY public."USER_AUTH"
    ADD CONSTRAINT user_auth_fkey_customer_info FOREIGN KEY ("CUST_ID") REFERENCES public."CUSTOMER_INFO"("CUST_ID");
 R   ALTER TABLE ONLY public."USER_AUTH" DROP CONSTRAINT user_auth_fkey_customer_info;
       public          postgres    false    2813    206    207            �   �   x���=N�@���S�l�:?��k+r���A�)R�
����-q NA��E��ބ��f���7���9J�E��_��AS�v�I�E8��Q,!��}�!c~LM�Li�]SѴ5ح�ga�:����]`��䓾��L��Ҵ3���Ab6��]��۟vf�nI�����[ҫk�H��-�8#�� B0T:ϫ���*�?��D	����-!��v��w$wC�z���Q��,��*/>~��"�<�8�u=      �   �   x�����0E��+�WH- ʮN�h��hb����e�!�ۙ䜹s+ē����ka)�,��dM�������0@/��*Vy�����8�R����Z%s�M��HQu�/Z��찣�铴�E2ϦYV�tg����ƣt�����WI��.I^��fiG�B�����/����o�_�Yy/���� �!��=ڷ�cE��ꈋ      �   '  x����N�0���)n�T	BAtK�nm%�C��"U��t�����s#�D�=�&�	�����X,ٺ���߂ҝ^'��y�a�	�Td��z��qs|/���C�Zq��Aӳ��=yw^�/�yx9��0
��«�'сS)�O�^�{��3]�4�N6���V�@�p{rS=H�1^p(���W���b	�Ʉ׿O0�������rBGэam���߬x;�#&���9��飱��������%d�3 �P�˘��۬�: ���ҝ�N�� &�O���1���ng��S��      �   �   x�ssu�	rt��s�700��8ܫ�p�_��ý~
�
.ww9{(8{<ܽ��]����p�g�k���_������������g$'�hN7�5���!���\!�(ֆx�>ܵO!���O!$�p��|���O�	h)�@�E�g������ <^K"      �   �   x�s�t���w���9���p�
?w�χ��8�=<�B\�\�C@�HNC3+cs+CC=#S3Sms,B\0M���a�~��!�*�?�=ϓ"�0��d.s�T�ur���P
 9�`�Ě���� �H�      �   n   x�s�t�700��9���p�
?w���c�����pw�����F?]�����x*x<ܵ�O!�1R��(�s�prv��44��44�463�t��������� � "      �   y   x�m���0Dg�+X:�F�Ď�7&��lH��w�B[	Q��{�ӵ>+�]���8)&-a��d�'Eq�������v����v����RR������e�k�s��,�R�6��+0�ˋ*-      �      x������ � �      �      x������ � �      �   b   x�sr��w�tsu�	rt��s�700��4202�50�50�42�2��25ѳ075�4�60�"��5*�1�R�|��=���<��2d��=... e�C�      �   �   x�sr��w��=<E��p�������.?��(�=�=�S���p�P��ϝ3Ə3�����@��L�����������\������X�����c���_|�g�!�M!�<�=��Z� Q�VB�%1z\\\ �%8b      �   G   x�sr��w���540���44�22�22�34�46��60�"�������`�jJ�Ns�u��qqq ��$@      �      x������ � �      �   '  x���KN�0���{"�Q�K�8q�b[��T)ga��=8���$�	��	)k���<v*Dm7,�UVS���W��L��ٿpI�l�o*#+��
��p�,HU�N�E��R
[H�J$��ua5_A 	�
�x���.���`�K���8�1F�-QXt�p�[�p�	}�g�.-��<��^�N������i��%��:.��-����'^�l��6�����e��A��ܷ����e���]m�M����9+�ui~%��{��J;5�?l�����?�N_�`�/�;��O+�ǈ      �   /   x�300w6 sNO?N�����Ԍ3����(j-������� \p)      �      x������ � �      �      x������ � �      �      x�s�t���w���9���p�
?w�χ��8c`(�����@��T��B��������X������P�����/�5�58$>�1���b�����y�2�������L�������(���#�wJ� �7      �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    16393    WeTrade    DATABASE     �   CREATE DATABASE "WeTrade" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'English_United States.1252' LC_CTYPE = 'English_United States.1252';
    DROP DATABASE "WeTrade";
                postgres    false            �           0    0    DATABASE "WeTrade"    COMMENT     4   COMMENT ON DATABASE "WeTrade" IS 'WeTrade Project';
                   postgres    false    2998                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                postgres    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   postgres    false    3            �            1255    16893    123(character varying)    FUNCTION     �   CREATE FUNCTION public."123"(in_clientid character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  one numeric;
  two numeric;
BEGIN
  one := 1;
  two := 2;
  RETURN one + two;
END;
$$;
 ;   DROP FUNCTION public."123"(in_clientid character varying);
       public          postgres    false    3            �            1255    17446 V   fnc_check_stock_info(character varying, character varying, character varying, integer)    FUNCTION     L
  CREATE FUNCTION public.fnc_check_stock_info(in_stocksymbol character varying, in_ordertype character varying, in_price character varying, in_quantity integer, OUT out_marketid character varying, OUT out_price numeric, OUT out_marginstockratio integer, OUT out_margincapprice numeric, OUT out_closingprice numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  13/06/2020
	-- Desc: Kiểm tra tính hợp lệ của thông tin cổ phiếu khi đặt lệnh -> kiểm tra giá, số lượng, mã cổ phiếu	
	-- Input: 	in_StockSymbol -> mã chứng khoán
	--			in_OrderType -> Loại lệnh: BUY/SELL
	--			in_Price -> giá đặt: ATO/ATC/MP/MOK/MAK/MTL ...
	--			in_Quantity -> Số lượng đặt
	-- Output: 	out_MarketID -> Sàn của mã chứng khoán
	--			out_Price -> mức giá sử dụng
	--			out_MarginStockRatio -> Tỷ lệ ký quỹ của mã chứng khoán
	--			out_ErrNum -> Mã lỗi 
DECLARE
	v_CellingPrice numeric := 0; -- giá trần
	v_FloorCelling	numeric := 0; -- giá sàn
	v_ClosingPrice	numeric := 0; -- giá tham chiếu
	v_MarketID		varchar(50) := ''; -- sàn
	v_MarginCapPrice  numeric := 0;
	v_MarginStockRatio int := 0;
	v_Price numeric := 0;
	v_StockType varchar(20);
	v_LotSize int := 0;
BEGIN
	SELECT a.EXCHG_CD, a.STOCK_TYPE, a.LOT_SIZE, a.CLOSE_PRICE, a.FLOOR_PRICE, a.CEILING_PRICE, a.MARGIN_CAP_PRICE, a.MARGIN_RATIO
		INTO v_MarketID, v_StockType, v_LotSize, v_ClosingPrice, v_FloorCelling, v_CellingPrice, v_MarginCapPrice, v_MarginStockRatio
	FROM STOCK_INFO a
	where STOCK_NO = in_StockSymbol AND STOCK_STATUS = 'N';
	
	IF NOT FOUND THEN
		out_MarketID := '';
		out_Price	:= 0;
		out_MarginStockRatio := 0;
		out_MarginCapPrice := 0;
		out_ClosingPrice := 0;
		out_ErrNum := 'STI001'; -- Mã chứng khoán không hợp lệ
		return;
	END IF;
	out_MarketID := v_MarketID;
	out_MarginStockRatio := v_MarginStockRatio;
	out_MarginCapPrice := v_MarginCapPrice;
	out_ClosingPrice := v_ClosingPrice;
	IF in_Price IN ('ATO','ATC','MP','MOK','MAK','MTL') THEN
		IF in_OrderType == 'B' THEN
			out_Price := v_CellingPrice;
		ELSE
			out_Price := v_FloorCelling;
		END IF;
	ELSE
		select to_number(in_Price,'9G999g999') INTO v_Price;
		IF (v_Price > v_CellingPrice) OR (v_Price < v_FloorCelling) THEN
			out_Price := v_Price;
			out_ErrNum := 'STI002'; -- Giá không hợp lệ
			return;
		ELSE
			out_Price := v_Price;
		END IF;
	END IF;
	
	IF MOD(in_Quantity, v_LotSize) != 0 THEN
		out_ErrNum := 'STI003'; -- Số lượng không hợp lệ
		return;	
	END IF;	
	out_ErrNum := 'STI000'; -- Hợp lệ
	return;	
END;
$$;
 [  DROP FUNCTION public.fnc_check_stock_info(in_stocksymbol character varying, in_ordertype character varying, in_price character varying, in_quantity integer, OUT out_marketid character varying, OUT out_price numeric, OUT out_marginstockratio integer, OUT out_margincapprice numeric, OUT out_closingprice numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    17041 '   fnc_get_cash_balance(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_cash_balance(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: function to get client cash balance
	-- Input: ClientID
	-- Output: return cashbalance	
DECLARE
	v_OpenCashBal numeric := 0;
	v_Cashonhold numeric := 0;
	-- v_Buyamt_Unmatch numeric := 0; -- > Mua chưa khớp đã tính trong số tiền hold
	v_CashDeposit numeric := 0;		
	v_CashBal		numeric := 0;
BEGIN
	SELECT a.opencashbal, a.cashdeposit, a.cashonhold -- , a.buyamt_unmatch
		INTO v_OpenCashBal, v_CashDeposit, v_Cashonhold -- , v_Buyamt_Unmatch
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		v_OpenCashBal := 0;
		v_CashDeposit := 0;
		v_Cashonhold := 0;
		-- v_Buyamt_Unmatch := 0;
	END IF;

	v_CashBal := v_OpenCashBal + v_CashDeposit - v_Cashonhold; -- - v_Buyamt_Unmatch;
	RETURN v_CashBal;
END; $$;
 J   DROP FUNCTION public.fnc_get_cash_balance(in_clientid character varying);
       public          postgres    false    3            �            1255    17475 "   fnc_get_fee_tax(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_fee_tax(in_productid character varying, OUT out_fee_value numeric, OUT out_tax_value numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
-- 	v_Units varchar(50); -- Đơn vị tính
-- 	v_MarketID varchar(50); -- Sàn giao dịch
-- 	v_StockType varchar(50); -- Loại chứng khoán
-- 	v_Channel varchar(50); -- Kênh giao dịch
-- 	v_MaxValue numeric; -- Chặn trên
-- 	v_MinValue numeric; -- Chặn dưới
	v_Values1 numeric; -- Giá trị
	v_Values2 numeric; -- Giá trị
BEGIN
	SELECT a.VALUES INTO out_fee_value
	FROM TEST_FEE_SETTING a
	WHERE a.FEE_ID = 'FEE_TRADE_STOCK' AND a.ACTIVE_YN = 'Y' AND a.RULES='TRADING'
		AND a.NAME_ID in (SELECT FEE_ID FROM PRODUCT_FEE WHERE PRODUCT_ID=in_ProductID);
	
	IF NOT FOUND THEN
		v_Values1 := 0.35;
	END IF;
	
	SELECT a.VALUES INTO out_tax_value
	FROM TEST_FEE_SETTING a
	WHERE a.FEE_ID = 'TAX_TRADE_STOCK' AND a.ACTIVE_YN = 'Y' AND a.RULES='TRADING'
		AND a.NAME_ID in (SELECT FEE_ID FROM PRODUCT_FEE WHERE PRODUCT_ID=in_ProductID);
		
	IF NOT FOUND THEN
		v_Values2 := 0.1;
	END IF;

	out_fee_value := v_Values1 / 100;
	out_tax_value := v_Values2 / 100;
END; $$;
 |   DROP FUNCTION public.fnc_get_fee_tax(in_productid character varying, OUT out_fee_value numeric, OUT out_tax_value numeric);
       public          postgres    false    3            �            1255    17524 �   fnc_get_fee_with_options(character varying, character varying, character varying, character varying, character varying, character varying, numeric)    FUNCTION     ,  CREATE FUNCTION public.fnc_get_fee_with_options(in_productid character varying, in_type character varying, in_option character varying, in_market character varying, in_stocktype character varying, in_channel character varying, in_value numeric, OUT out_fee_value numeric, OUT out_fee_name_id character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_Units varchar(50); -- Đơn vị tính
	v_MarketID varchar(50); -- Sàn giao dịch
	v_StockType varchar(50); -- Loại chứng khoán
	v_Channel varchar(50); -- Kênh giao dịch
	v_MaxValue numeric; -- Chặn trên
	v_MinValue numeric; -- Chặn dưới
	v_Temp_Values numeric; -- Giá trị
	v_SQL varchar;
	json_data json;
	item json;
	v_Temp_Priority int;
	v_Count int := 0;
	v_Temp_Priority1 int;
	v_Temp_Values1 numeric;
	v_Values numeric;
	
BEGIN
	v_SQL := 'SELECT json_agg(z) FROM (SELECT t."NAME_ID", t."UNITS", t."MARKETID",  t."STOCK_TYPE", t."CHANNEL", t."MAX_VALUES", t."MIN_VALUES", t."VALUES", t."PRIORITY"';
	v_SQL := v_SQL || E' FROM public."TEST_FEE_SETTING" t WHERE t."ACTIVE_YN"=''Y'' AND t."RULES" = ''' ||  in_Type || ''' AND ( ';
	
	IF (in_Market IS NOT NULL) OR (length(in_Market) > 1) THEN
		v_SQL := v_SQL || ' t."MARKETID" ='''|| in_Market || '''';
	END IF;
	
	IF (in_StockType IS NOT NULL) OR (length(in_StockType) > 1) THEN
		v_SQL := v_SQL || ' OR t."STOCK_TYPE" ='''|| in_StockType || '''';
	END IF;
	
	IF (in_Channel IS NOT NULL) OR (length(in_Channel) > 1) THEN
		v_SQL := v_SQL || ' OR t."CHANNEL" ='''|| in_Channel || '''';
	END IF;
	
	IF (in_Value IS NOT NULL) OR (in_Value > 0) THEN
		v_SQL := v_SQL || ' OR (t."MIN_VALUES" <= ' || in_Value || ' AND t."MAX_VALUES" > '|| in_Value || ')';
	END IF;
	
	v_SQL := v_SQL || '))z;';
	
	RAISE NOTICE 'Parsing %',v_SQL;
	EXECUTE v_SQL INTO json_data ;
	
	raise notice 'jsonb_array_length(js):       %', json_array_length(json_data);
	raise notice 'jsonb_DATA:       %', json_data;
	FOR item IN SELECT * FROM json_array_elements(json_data)
  	LOOP
		IF v_Count=0 THEN
			v_Temp_Priority := item ->>'PRIORITY';
			v_Temp_Values := item ->>'VALUES';
			v_Values := v_Temp_Values;
			out_FEE_NAME_ID := item ->>'NAME_ID';
		ELSE
			v_Temp_Priority1 := item ->>'PRIORITY';
			v_Temp_Values1 := item ->>'VALUES';
			IF in_Option = 'PRIORITY' THEN -- Lấy phí ưu tiên nhất (độ ưu tiên nhỏ nhất)
			RAISE NOTICE 'vO ƯU TIEN';
				IF v_Temp_Priority1	< v_Temp_Priority THEN
					v_Values := v_Temp_Values1;					
					out_FEE_NAME_ID := item ->>'NAME_ID';
				END IF;				
			END IF;	
			RAISE NOTICE 'Values0  %',v_Values;
			IF in_Option = 'VALUES' THEN -- Lấy phí nhỏ nhất
				RAISE NOTICE 'vO GIA TRI';
				IF v_Temp_Values1 < v_Temp_Values THEN
					v_Values := v_Temp_Values1;
					RAISE NOTICE 'Values  % %',v_Count, v_Values;
					out_FEE_NAME_ID := item ->>'NAME_ID';
				END IF;					
			END IF;	
			v_Temp_Priority := v_Temp_Priority1;
			v_Temp_Values := v_Temp_Values1;
		END IF;
		v_Count := v_Count+1;
	END LOOP;
	out_fee_value := v_Values;
END; $$;
 6  DROP FUNCTION public.fnc_get_fee_with_options(in_productid character varying, in_type character varying, in_option character varying, in_market character varying, in_stocktype character varying, in_channel character varying, in_value numeric, OUT out_fee_value numeric, OUT out_fee_name_id character varying);
       public          postgres    false    3            �            1255    17036 <   fnc_get_margin_dividend(character varying, numeric, numeric)    FUNCTION     w  CREATE FUNCTION public.fnc_get_margin_dividend(in_clientid character varying, in_margin_ratio numeric, in_tax_rate numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200606
	-- Desc: Lấy tiền cổ tức chờ về được tính làm tài sản đảm bảo đối với tài khoản margin
	-- Input: 	ClientID
	--			Margin ration: tỷ lệ ký quỹ (đã chia % -> ví dụ: 0.5 - 0.7 ...)
	--			Tax_Rate: phần trăm thuế TNCN phải nộp trên tiền cổ tức ( đã chia % -> ví dụ: 0.001)
	-- Output: return Margin_Dividend	
DECLARE
	v_expected_dividend numeric; -- tiền cổ tức chờ về
	v_margin_Dividend numeric; -- tiền cổ tức được tính làm tài sản đảm bảo
BEGIN
	SELECT a.expected_dividend
		INTO v_expected_dividend
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		v_expected_dividend := 0;
	END IF;

	v_margin_Dividend := v_expected_dividend * (1 - in_Tax_Rate) * in_Margin_Ratio;
	RETURN v_margin_Dividend;
END; $$;
 {   DROP FUNCTION public.fnc_get_margin_dividend(in_clientid character varying, in_margin_ratio numeric, in_tax_rate numeric);
       public          postgres    false    3            �            1255    16903 $   fnc_get_total_cia(character varying)    FUNCTION     <  CREATE FUNCTION public.fnc_get_total_cia(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: lấy tổng giá ứng trước tiền bán
	-- Input: ClientID
	-- Output: return total_margin_devidend	
	-------- = SellAmt_T + SellAmt_T1 + SellAmt_T2 - CIA_Used_T - CIA_Used_T1 - CIA_Used_T2 - PendingCIA
DECLARE
	sellAmt_T numeric; -- dự nợ đã giản ngân
	sellAmt_T1 numeric; -- lãi vay tạm tính
	sellAmt_T2 numeric; -- dư nợ dự kiến giải ngân
	CIA_Used_T numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	CIA_Used_T1 numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	CIA_Used_T2 numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	pending_CIA numeric; -- 
	total_CIA_Used numeric; ---
	total_sellAmt numeric; ---
	total_CIA_Avail numeric;
BEGIN
	SELECT a.sellamt_T, a.sellamt_T1, a.sellamt_T2, 
	a.cia_used_T, a.cia_used_T1, a.cia_used_T2, a.pending_CIA
		INTO sellAmt_T, sellAmt_T1, sellAmt_T2, CIA_Used_T, CIA_Used_T1, CIA_Used_T2, pending_CIA
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		sellAmt_T := 0;
		sellAmt_T1 := 0;
		sellAmt_T2 := 0;
		CIA_Used_T := 0;
		CIA_Used_T1 := 0;
		CIA_Used_T2 := 0;
		pending_CIA := 0;
	END IF;

	total_CIA_Used := CIA_Used_T + CIA_Used_T1 + CIA_Used_T2 + pending_CIA;
	total_sellAmt := sellAmt_T + sellAmt_T1 + sellAmt_T2 ;
	total_CIA_Avail := total_sellAmt - total_CIA_Used;
	if (total_sellAmt - total_CIA_Used) >= 0 THEN
		total_CIA_Avail := total_sellAmt - total_CIA_Used;
	ELSE
		total_CIA_Avail := 0;
	END IF;
	RETURN total_CIA_Avail;
END; $$;
 G   DROP FUNCTION public.fnc_get_total_cia(in_clientid character varying);
       public          postgres    false    3            �            1255    16900 %   fnc_get_total_loan(character varying)    FUNCTION       CREATE FUNCTION public.fnc_get_total_loan(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: lấy tổng dư nợ
	-- Input: ClientID
	-- Output: return cashbalance	
DECLARE
	debitInterest numeric; -- lãi vay tạm tính
	preLoan numeric; -- dư nợ dự kiến giải ngân		
	debitAmt numeric; -- dự nợ đã giản ngân
	othersFree numeric; -- Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …
	total_Loan numeric; -- tổng dư nợ
BEGIN
	SELECT a.debitinterest, a.pre_loan, a.debitamt, a.others_free
		INTO debitInterest, preLoan, debitAmt, othersFree
	FROM client_cash_bal a
	WHERE a.clientid = in_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_cash_bal b where b.clientid = in_ClientID);
	
	IF NOT FOUND THEN
		debitInterest := 0;
		preLoan := 0;
		debitAmt := 0;
		othersFree := 0;
	END IF;

	total_Loan := debitInterest + preLoan + debitAmt + othersFree;
	RETURN total_Loan;
END; $$;
 H   DROP FUNCTION public.fnc_get_total_loan(in_clientid character varying);
       public          postgres    false    3            �            1255    17040 .   fnc_get_total_margin_values(character varying)    FUNCTION     �  CREATE FUNCTION public.fnc_get_total_margin_values(in_clientid character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200606
	-- Desc: Lấy tổng giá trị chứng khoán được tính làm tài sản đảm bảo cho tài khoản ký quỹ
	--		Chứng khoán được tính làm tài sản đảm bảo là chứng khoán được phép giao dịch ký quỹ 
	-- Input: 	ClientID
	--			Margin ration: tỷ lệ ký quỹ (đã chia % -> ví dụ: 0.5 - 0.7 ...)
	-- Output: return total_margin_values	
DECLARE
	-- =OnHand - Sold - SellT1 - SellT2 - HoldForBlock - HoldForTemp - HoldForTrade +Dep/With + BuyT1+BuyT2+Bonus
	v_Stock_Symbol varchar(20); -- Mã chứng khoán
	v_OnHand numeric := 0; -- số lượng chứng khoán có trong tài khoản
	v_Sell numeric := 0; -- Số lượng chứng khoán bán trong ngày (khớp và chưa khớp)
	v_SellT1 numeric := 0; -- Số lượng chứng khoán khớp bán ngày T1
	v_SellT2 numeric := 0; -- Số lượng chứng khoán khớp bán ngày T2
	v_HoldForBlock numeric := 0; -- Số lượng chứng khoán tạm phong tỏa
	v_HoldForTemp numeric := 0; -- Số lượng chứng khoán bị phong tỏa
	v_HoldForTrade numeric := 0; -- SLCP chờ giao dịch. ???
	v_Dep_With numeric := 0; -- Số lượng chứng khoán nộp/rút
	v_BuyT1 numeric := 0; -- Số lượng chứng khoán mua ngày T1
	v_BuyT2 numeric := 0; -- Số lượng chứng khoán mua ngày T2
	v_Bonus numeric := 0; -- Số lượng cổ phiếu thưởng, cổ tức bằng cổ phiếu ...
	v_Margin_Price numeric := 0; -- Giá margin
	v_Margin_Stock_Ratio numeric := 0; -- Tỷ lệ ký quỹ của cổ phiếu
	v_Quantity numeric  := 0; -- Số lượng cổ phiếu tính làm TSDB
	v_Total_Margin_Value numeric  := 0; --
	v_Temp_Value numeric := 0; 
	rec_portfolio   RECORD;
	curs_portfolio CURSOR (t_ClientID varchar) FOR
		SELECT a.stock_symbol, a.on_hand, a.sell_t, a.sell_t1, a.sell_t2,
		a.hold_for_block, a.hold_for_temp, a.hold_for_trade, a.dep_with, a.bonus, a.buy_t1, a.buy_t2	
	FROM client_stock_bal a
	WHERE a.clientid = t_ClientID
		AND a.tradedate in (SELECT MAX(b.tradedate) FROM client_stock_bal b where b.clientid = t_ClientID);
BEGIN
	OPEN curs_portfolio(in_ClientID);
	LOOP
		-- fetch row into the film
		FETCH curs_portfolio INTO rec_portfolio;
		-- exit when no more row to fetch
		EXIT WHEN NOT FOUND;
		v_Stock_Symbol := rec_portfolio.stock_symbol;
		v_OnHand := rec_portfolio.on_hand;
		v_Sell := rec_portfolio.sell_t;
		v_SellT1 := rec_portfolio.sell_t1;
		v_SellT2 := rec_portfolio.sell_t2;
		v_HoldForBlock := rec_portfolio.hold_for_block;
		v_HoldForTemp := rec_portfolio.hold_for_temp;
		v_HoldForTrade := rec_portfolio.hold_for_trade;
		v_Bonus := rec_portfolio.bonus;
		v_Dep_With := rec_portfolio.dep_with;
		v_BuyT1 := rec_portfolio.buy_t1;
		v_BuyT2 := rec_portfolio.buy_t2;
		v_Quantity = v_OnHand - v_Sell - v_SellT1 - v_SellT2- v_HoldForBlock - v_HoldForTemp - v_HoldForTrade + v_Dep_With + v_BuyT1 + v_BuyT2 + v_Bonus;

		SELECT LEAST(s.MARGIN_CAP_PRICE, s.CLOSE_PRICE) as margin_price,  s.MARGIN_RATIO 
			INTO v_Margin_Price, v_Margin_Stock_Ratio
		FROM STOCK_INFO s 
		where s.STOCK_NO = v_Stock_Symbol;
		
		IF NOT FOUND THEN
			v_Margin_Price := 0;
			v_Margin_Stock_Ratio := 1;
		END IF;
		v_Temp_Value := v_Quantity * v_Margin_Price * v_Margin_Stock_Ratio;

		v_Total_Margin_Value := v_Total_Margin_Value + v_Temp_Value;	
	END LOOP;

   -- Close the cursor
	CLOSE curs_portfolio;	

	RETURN v_Total_Margin_Value;
END; $$;
 Q   DROP FUNCTION public.fnc_get_total_margin_values(in_clientid character varying);
       public          postgres    false    3            �            1255    17413 D   fnc_get_trading_power(character varying, numeric, character varying)    FUNCTION     b  CREATE FUNCTION public.fnc_get_trading_power(in_clientid character varying, in_margin_ratio numeric, in_stock_symbol character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Tính sức mua
	-- Input: ClientID
	--			Margin Ratio
	--			Stock Symbol
	-- Output: return cashbalance	
DECLARE
	v_Total_Loan numeric := 0; -- Tổng dư nợ
	v_Margin_Dividend numeric := 0; -- Tiền cổ tức chờ về		
	v_Total_CIA numeric := 0; -- Ứng trước tiền bán
	v_Total_Margin_Market_Values numeric := 0; -- Tổng giá trị chứng khoán ký quỹ
	v_Cash_Balance numeric := 0; -- Tổng số dư tiền mặt
	v_Available_Balance numeric := 0; -- Số dư tiền
	v_Stock_Margin_Ratio numeric :=0; -- Tỷ lệ ký quỹ của cổ phiếu muốn mua
	v_Trading_Power numeric := 0; -- Sức mua
BEGIN
	SELECT s.MARGIN_RATIO 
			INTO v_Stock_Margin_Ratio
		FROM STOCK_INFO s 
		where s.STOCK_NO = in_Stock_Symbol;
	
	IF NOT FOUND THEN
		v_Stock_Margin_Ratio := 1;
	END IF;
	SELECT fnc_get_total_margin_values(in_ClientID) INTO v_Total_Margin_Market_Values;
	SELECT fnc_get_total_loan(in_ClientID) INTO v_Total_Loan;
	SELECT fnc_get_total_cia(in_ClientID) INTO v_Total_CIA;
	SELECT fnc_get_margin_dividend(in_ClientID) INTO v_Margin_Dividend;
	SELECT fnc_get_cash_balance(in_ClientID) INTO v_Cash_Balance;
	
	v_Available_Balance := v_Cash_Balance - v_Total_Loan + v_Total_CIA + v_Margin_Dividend;
	
	v_Trading_Power = ( v_Available_Balance + v_Total_Margin_Market_Values * in_Margin_Ratio) / (1 - in_Margin_Ratio * v_Stock_Margin_Ratio);
	
	RETURN v_Trading_Power;
END; $$;
 �   DROP FUNCTION public.fnc_get_trading_power(in_clientid character varying, in_margin_ratio numeric, in_stock_symbol character varying);
       public          postgres    false    3            �            1255    17544 3   fucn_check_account_info(character varying, numeric)    FUNCTION     �  CREATE FUNCTION public.fucn_check_account_info(in_clientid character varying, in_marginratio numeric, OUT out_productid character varying, OUT out_marginlimit numeric, OUT out_errnum character varying, OUT out_branchno integer, OUT out_brokerid character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Kiểm tra thông tin tài khoản của khách hàng
	-- Input: 	in_ClientID -> mã khách hàng
	--			in_MarginRatio -> Tỷ lệ ký quỹ sử dụng (nếu tài khoản bankGW = 0)
	-- Output: 	out_ErrNum -> Mã lỗi ACC0000 -> Thành công
DECLARE
	v_ProDuctID varchar(50); -- Loại tài khoản của khách hàng
	v_BranchNo int := 0;
	v_BrokerID varchar(50);
	v_MarginRatio numeric := 0;
	v_MarginLimit numeric := 0;
BEGIN
	-- Lấy thông tin loại tài khoản của khách hàng
	SELECT "ACCT_TYPE", "BRANCH_NO", "BROKER_ID" INTO v_ProDuctID, v_BranchNo, v_BrokerID
	FROM public."CUSTOMER_INFO" t WHERE t."ACCT_STATUS"='ACTIVE' AND t."CUST_ID" = in_ClientID;
	
	IF NOT FOUND THEN
		out_ErrNum := 'ACC0001'; -- Account không tồn tại
		return;
	END IF;

	-- Check tỷ lệ ký quỹ ứng 
	SELECT z."MARGIN_RATIO", z."MARGIN_LIMIT"
		INTO v_MarginRatio, v_MarginLimit
	FROM public."MARGIN_SETTING" z 
	where z."ACTIVE_YN"='Y' AND z."MARGIN_RATIO" = in_MarginRatio
		AND EXISTS (SELECT 1 FROM public."PRODUCT_SETTING" a WHERE a."ACTIVE_YN"='Y' AND a."MARGIN_ID"=z."MARGIN_ID" AND a."PRODUCT_ID" = v_ProDuctID);
		
	IF NOT FOUND THEN
		out_ErrNum := 'ACC0002'; -- Tỷ lệ ký quỹ không hợp lệ
		return;
	END IF;
	out_ProductID := v_ProDuctID;
	out_MarginLimit := v_MarginLimit;
	out_BranchNo := v_BranchNo;
	out_BrokerID := v_BrokerID;
	out_ErrNum := 'ACC000';
END; $$;
   DROP FUNCTION public.fucn_check_account_info(in_clientid character varying, in_marginratio numeric, OUT out_productid character varying, OUT out_marginlimit numeric, OUT out_errnum character varying, OUT out_branchno integer, OUT out_brokerid character varying);
       public          postgres    false    3            �            1255    17542 �   func_add_order(character varying, character varying, character varying, character varying, character varying, numeric, character varying, numeric, integer, character varying, character varying, numeric, date)    FUNCTION     �  CREATE FUNCTION public.func_add_order(in_clientid character varying, in_marketid character varying, in_channel character varying, in_stocksymbol character varying, in_price character varying, in_quantity numeric, in_ordertype character varying, in_totalvalue numeric, in_branchno integer, in_tradeid character varying, in_brokerid character varying, in_feepct numeric, in_tradedate date, OUT out_sysorder numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_ErrNum varchar(20); -- Đơn vị tính
	v_SysOrderNo bigint; 
	v_OrderStatus varchar(20) := 'RS'; --
	v_DMAFlag character := 'Y';
	v_MarketID varchar(50);
	v_Price numeric;
	v_MarginStockRatio integer;
	v_MarginCapPrice numeric;
	v_ClosingPrice numeric;
	v_Tax numeric;
	v_Fee numeric;
	v_TotalValue numeric;
	v_OrderValue numeric;
	v_FeeValue numeric;
	v_TaxValue numeric;
	v_TradingPower numeric;
BEGIN
	SELECT nextval('ORDER_SQ') INTO v_SysOrderNo;
	INSERT INTO public."ORDER"(
		"SYS_ORDER_NO", "EXCHG_CD", "CHANNEL", "ORDER_STATUS", "STOCK_CD", "ORDER_PRICE", "ORDER_QTY", "BID_ASK_TYPE", 
		"BRANCH_NO", "EXCHG_ORDER_TYPE", "CUST_ID",  "PARENT_ORDER_NO", "TRADE_ID", "BROKER_ID", 
		"DMA_FLAG",  "FREE_PCT", "LAST_UPD_DT", "TRADE_DATE")
	VALUES(v_SysOrderNo, in_MarketID, in_Channel, v_OrderStatus, in_StockSymbol, in_Price, in_Quantity, in_OrderType,
		  in_BranchNo, in_OrderType, in_ClientID, 0, in_TradeID, in_BrokerID, v_DMAFlag, in_FeePCT, CURRENT_TIMESTAMP, in_TradeDate);

	IF in_OrderType = 'B' THEN
		insert into	public.client_stock_bal( clientid,
											tradedate,
											marketid,
											stock_symbol,
											buy_t,
											update_time)
		values(in_ClientID, 
			   in_TradeDate, 
			   in_MarketID, 
			   in_StockSymbol, 
			   in_Quantity, 
			   CURRENT_TIMESTAMP)
		ON CONFLICT (clientid, tradedate, marketid, stock_symbol) 
		DO
			UPDATE 
			SET buy_t = in_Quantity
			WHERE  clientid = in_ClientID AND tradedate = in_TradeDate and marketid=in_MarketID AND stock_symbol=in_StockSymbol;
		-- CẬP NHẬT LẠI SỐ DƯ TIỀN
		update public."client_cash_bal"
		set	cashonhold =in_TotalValue,	buyamt_unmatch = in_TotalValue,	update_time = CURRENT_TIMESTAMP
		where clientid = in_ClientID AND tradedate = in_TradeDate;
	END IF;
	
	IF in_OrderType = 'S' THEN
		-- Giảm số lượng chứng khoán có thể mua
		UPDATE public."client_stock_bal"
		SET sellable = sellable - in_Quantity
		WHERE  clientid = in_ClientID AND tradedate = in_TradeDate and marketid=in_MarketID AND stock_symbol=in_StockSymbol;
	END IF;
	out_ErrNum := 'ODR000'; -- THÀNH CÔNG
	COMMIT;
EXCEPTION
   WHEN OTHERS THEN
   out_ErrNum := SQLERRM || SQLSTATE;
   ROLLBACK;
END; $$;
 �  DROP FUNCTION public.func_add_order(in_clientid character varying, in_marketid character varying, in_channel character varying, in_stocksymbol character varying, in_price character varying, in_quantity numeric, in_ordertype character varying, in_totalvalue numeric, in_branchno integer, in_tradeid character varying, in_brokerid character varying, in_feepct numeric, in_tradedate date, OUT out_sysorder numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    17545 �   func_execute_order(character varying, character varying, character varying, character varying, numeric, character varying, numeric)    FUNCTION       CREATE FUNCTION public.func_execute_order(in_clientid character varying, in_channel character varying, in_ordertype character varying, in_stocksymbol character varying, in_quantity numeric, in_price character varying, in_marginratio numeric, OUT out_sysorder numeric, OUT out_errnum character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: Lấy giá trị phí và thuế dùng trong giao dịch
	-- 		Tạm thời dùng 1 loại phí
	-- Input: 	in_ProductID -> mã sản phẩm
	--			in_Type -> Loại phí, thuế
	-- Output: 	out_fee_value -> giá trị thuế
	--			out_tax_value -> Giá trị thuế
	-- 			out_ErrNum -> mã lỗi
DECLARE
	v_ErrNum varchar(20); -- Đơn vị tính
	v_ProDuctID varchar(50); -- Loại tài khoản của khách hàng
	v_BranchNo int := 0;
	v_BrokerID varchar(50);
	v_MarginLimit numeric := 0; --
	v_MarketID varchar(50);
	v_Price numeric;
	v_MarginStockRatio integer;
	v_MarginCapPrice numeric;
	v_ClosingPrice numeric;
	v_Tax numeric;
	v_Fee numeric;
	v_TotalValue numeric;
	v_OrderValue numeric;
	v_FeeValue numeric;
	v_TaxValue numeric;
	v_TradingPower numeric;
	v_Sellable numeric := 0;
	v_SysOrderNo numeric := 0;
BEGIN
	-- Kiểm tra thông tin khách hàng, nếu không hợp lệ thì báo lỗi
	SELECT * FROM fucn_check_account_info(in_ClientID,in_MarginRatio) INTO v_ProDuctID, v_MarginLimit, v_ErrNum, v_BranchNo, v_BrokerID;	
	IF v_ErrNum <> 'ACC000' THEN
		out_ErrNum := v_ErrNum;
		return;
	END IF;
	
	-- Kiểm tra thông tin lệnh đặt (bước giá, số lượng đặt )
	SELECT * FROM fnc_check_stock_info(in_StockSymbol, in_OrderType, in_Price, in_Quantity) 
		INTO v_MarketID, v_Price, v_MarginStockRatio, v_MarginCapPrice, v_ClosingPrice, v_ErrNum;
	IF v_ErrNum <> 'STI000' THEN
		out_ErrNum := v_ErrNum;
		return;
	END IF;
	
	-- Lấy giá trị thuế, phí giao dịch
	SELECT * FROM fnc_get_fee_tax(v_ProDuctID) INTO v_Fee, v_Tax;
	
	v_OrderValue := in_Quantity * v_Price;
	v_FeeValue := v_TotalValue * v_Fee;
	-- Xử lý lệnh mua
	IF in_OrderType = 'B' THEN
		-- Lấy sức mua
		SELECT fnc_get_trading_power(in_ClientID, in_MarginRatio, in_StockSymbol) INTO v_TradingPower;
		v_TotalValue := v_OrderValue + v_FeeValue;
		
		IF v_TotalValue > v_TradingPower THEN
			out_ErrNum := 'ODR001'; -- không đủ sức mua
			return;
		END IF;
	END IF;
	
	IF in_OrderType = 'S' THEN
		SELECT sellable INTO v_Sellable
		FROM public.client_stock_bal
		WHERE clientid = in_ClientID AND tradedate = CURRENT_DATE AND stock_symbol=in_StockSymbol;
		
		IF NOT FOUND THEN
			out_ErrNum := 'ODR002'; -- mã chứng khoán không có trong danh mục
			return;
		END IF;
		
		IF in_Quantity > v_Sellable THEN
			out_ErrNum := 'ODR003'; -- Số lượng đặt quá số lượng chứng khoán sở hữu
			return;
		END IF;		
	END IF;
	
	SELECT * FROM func_add_order(in_ClientID, v_MarketID, in_Channel, in_StockSymbol, v_Price, in_Quantity, in_OrderType, v_TotalValue, v_BranchNo, in_ClientID, v_BrokerID, v_Fee, CURRENT_DATE)
	INTO out_SysOrder, out_ErrNum;
END; $$;
 -  DROP FUNCTION public.func_execute_order(in_clientid character varying, in_channel character varying, in_ordertype character varying, in_stocksymbol character varying, in_quantity numeric, in_price character varying, in_marginratio numeric, OUT out_sysorder numeric, OUT out_errnum character varying);
       public          postgres    false    3            �            1255    16885    get_sum(numeric, numeric)    FUNCTION       CREATE FUNCTION public.get_sum(a numeric, b numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
	 -- Author: ThinhNT
	-- Date:  20200523
	-- Desc: function to get client cash balance
	-- Input: ClientID
	-- Output: return cashbalance	
BEGIN
	RETURN a + b;
END; $$;
 4   DROP FUNCTION public.get_sum(a numeric, b numeric);
       public          postgres    false    3            �            1255    17533     hi_lo(numeric, numeric, numeric)    FUNCTION     �   CREATE FUNCTION public.hi_lo(a numeric, b numeric, c numeric, OUT hi numeric, OUT lo numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
	hi := GREATEST(a,b,c);
	lo := LEAST(a,b,c);
END; $$;
 ]   DROP FUNCTION public.hi_lo(a numeric, b numeric, c numeric, OUT hi numeric, OUT lo numeric);
       public          postgres    false    3            �            1255    17443    sum_n_product(integer, integer)    FUNCTION     �   CREATE FUNCTION public.sum_n_product(x integer, y integer, OUT sum integer, OUT prod numeric) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF x = 0 THEN
		sum := 0;
		prod := 0;
		return;
	END IF;
    sum := x + y;
    prod := x * y;
END;
$$;
 ]   DROP FUNCTION public.sum_n_product(x integer, y integer, OUT sum integer, OUT prod numeric);
       public          postgres    false    3            �            1259    17090    CUSTOMER_INFO    TABLE     �  CREATE TABLE public."CUSTOMER_INFO" (
    "CUST_ID" character varying(50) NOT NULL,
    "CUST_NAME" character varying(100) NOT NULL,
    "TAX_ID" character varying(20),
    "ID_ISSUE_DATE" date,
    "ID_ISSUE_PLACE" character varying(20),
    "ID_TYPE" character(1),
    "BIRTH_DATE" date,
    "SEX" character varying(20),
    "MOBILE_PHONE" character varying(20),
    "FAX_NO" character varying(20),
    "ADDRESS_1" text,
    "ADDRESS_2" text,
    "NATIONALITY" character varying(20),
    "CUST_TYPE" character(1),
    "ACCT_TYPE" character varying(20),
    "BANK_ACCT" character varying(20),
    "BRANCH_NO" integer,
    "ACCT_STATUS" character varying(20),
    "BROKER_ID" character varying(20),
    "OPEN_DATE" timestamp without time zone,
    "CLOSE_DATE" timestamp without time zone,
    "UPD_DATE" timestamp without time zone,
    "OPEN_UID" character varying(20),
    "CLOSE_UID" character varying(20),
    "UPD_UID" character varying(20)
);
 #   DROP TABLE public."CUSTOMER_INFO";
       public         heap    postgres    false    3            �           0    0     COLUMN "CUSTOMER_INFO"."CUST_ID"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CUST_NAME"    COMMENT     M   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_NAME" IS 'Tên khách hàng';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."TAX_ID"    COMMENT     M   COMMENT ON COLUMN public."CUSTOMER_INFO"."TAX_ID" IS 'Số CMND / Passport';
          public          postgres    false    206            �           0    0 &   COLUMN "CUSTOMER_INFO"."ID_ISSUE_DATE"    COMMENT     Y   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_ISSUE_DATE" IS 'Ngày cấp CMND/Passport';
          public          postgres    false    206            �           0    0 '   COLUMN "CUSTOMER_INFO"."ID_ISSUE_PLACE"    COMMENT     Y   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_ISSUE_PLACE" IS 'Nơi cấp CMND/Passport';
          public          postgres    false    206            �           0    0     COLUMN "CUSTOMER_INFO"."ID_TYPE"    COMMENT     W   COMMENT ON COLUMN public."CUSTOMER_INFO"."ID_TYPE" IS 'Loại: 0: CMND - 1: Passport';
          public          postgres    false    206            �           0    0 #   COLUMN "CUSTOMER_INFO"."BIRTH_DATE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."BIRTH_DATE" IS 'Ngày tháng năm sinh';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."SEX"    COMMENT     B   COMMENT ON COLUMN public."CUSTOMER_INFO"."SEX" IS 'Giới tính';
          public          postgres    false    206            �           0    0 %   COLUMN "CUSTOMER_INFO"."MOBILE_PHONE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."MOBILE_PHONE" IS 'Số điện thoại';
          public          postgres    false    206            �           0    0    COLUMN "CUSTOMER_INFO"."FAX_NO"    COMMENT     A   COMMENT ON COLUMN public."CUSTOMER_INFO"."FAX_NO" IS 'Số Fax';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ADDRESS_1"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."ADDRESS_1" IS 'Địa chỉ 1';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ADDRESS_2"    COMMENT     J   COMMENT ON COLUMN public."CUSTOMER_INFO"."ADDRESS_2" IS 'Địa chỉ 2';
          public          postgres    false    206            �           0    0 $   COLUMN "CUSTOMER_INFO"."NATIONALITY"    COMMENT     K   COMMENT ON COLUMN public."CUSTOMER_INFO"."NATIONALITY" IS 'Quốc tịch';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CUST_TYPE"    COMMENT     p   COMMENT ON COLUMN public."CUSTOMER_INFO"."CUST_TYPE" IS 'Loại Khách hàng -> P: Cá nhân - O: Tổ chức';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."ACCT_TYPE"    COMMENT     l   COMMENT ON COLUMN public."CUSTOMER_INFO"."ACCT_TYPE" IS 'Loại tài khoản: bank hay margin hay VIP ...';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BANK_ACCT"    COMMENT     O   COMMENT ON COLUMN public."CUSTOMER_INFO"."BANK_ACCT" IS 'Tài khoản tiền';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BRANCH_NO"    COMMENT     F   COMMENT ON COLUMN public."CUSTOMER_INFO"."BRANCH_NO" IS 'Chi nhánh';
          public          postgres    false    206            �           0    0 $   COLUMN "CUSTOMER_INFO"."ACCT_STATUS"    COMMENT     m   COMMENT ON COLUMN public."CUSTOMER_INFO"."ACCT_STATUS" IS 'Trạng thái tài khoản: active/close/Freeze';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."BROKER_ID"    COMMENT     E   COMMENT ON COLUMN public."CUSTOMER_INFO"."BROKER_ID" IS 'Broker ID';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."OPEN_DATE"    COMMENT     S   COMMENT ON COLUMN public."CUSTOMER_INFO"."OPEN_DATE" IS 'Ngày mở tài khoản';
          public          postgres    false    206            �           0    0 #   COLUMN "CUSTOMER_INFO"."CLOSE_DATE"    COMMENT     V   COMMENT ON COLUMN public."CUSTOMER_INFO"."CLOSE_DATE" IS 'Ngày đóng tài khoản';
          public          postgres    false    206            �           0    0 !   COLUMN "CUSTOMER_INFO"."UPD_DATE"    COMMENT     Z   COMMENT ON COLUMN public."CUSTOMER_INFO"."UPD_DATE" IS 'Ngày cập nhật gần nhất';
          public          postgres    false    206            �           0    0 !   COLUMN "CUSTOMER_INFO"."OPEN_UID"    COMMENT     Q   COMMENT ON COLUMN public."CUSTOMER_INFO"."OPEN_UID" IS 'User mở tài khoản';
          public          postgres    false    206            �           0    0 "   COLUMN "CUSTOMER_INFO"."CLOSE_UID"    COMMENT     T   COMMENT ON COLUMN public."CUSTOMER_INFO"."CLOSE_UID" IS 'User đóng tài khoản';
          public          postgres    false    206            �           0    0     COLUMN "CUSTOMER_INFO"."UPD_UID"    COMMENT     k   COMMENT ON COLUMN public."CUSTOMER_INFO"."UPD_UID" IS 'User cập nhật tài khoản lần gần nhất';
          public          postgres    false    206            �            1259    16922    FEE_CATEGORY    TABLE       CREATE TABLE public."FEE_CATEGORY" (
    "FEE_ID" character varying(50) NOT NULL,
    "DESC_EN" text,
    "DESC_VN" text,
    "EFFECTIVE_DATE" date,
    "TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "LAST_UPDATED" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."FEE_CATEGORY";
       public         heap    postgres    false    3            �           0    0    COLUMN "FEE_CATEGORY"."FEE_ID"    COMMENT     l   COMMENT ON COLUMN public."FEE_CATEGORY"."FEE_ID" IS 'Mã phí giao dịch - số tự động tăng dần';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."DESC_EN"    COMMENT     R   COMMENT ON COLUMN public."FEE_CATEGORY"."DESC_EN" IS 'Diễn giải tiếng anh';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."DESC_VN"    COMMENT     U   COMMENT ON COLUMN public."FEE_CATEGORY"."DESC_VN" IS 'Diễn giải tiếng việt';
          public          postgres    false    204            �           0    0 &   COLUMN "FEE_CATEGORY"."EFFECTIVE_DATE"    COMMENT     P   COMMENT ON COLUMN public."FEE_CATEGORY"."EFFECTIVE_DATE" IS 'Ngày áp dụng';
          public          postgres    false    204            �           0    0    COLUMN "FEE_CATEGORY"."TYPE"    COMMENT     ^   COMMENT ON COLUMN public."FEE_CATEGORY"."TYPE" IS 'Loại phí: phần trăm, cố định)';
          public          postgres    false    204            �           0    0 !   COLUMN "FEE_CATEGORY"."ACTIVE_YN"    COMMENT     ^   COMMENT ON COLUMN public."FEE_CATEGORY"."ACTIVE_YN" IS 'Phí còn áp dụng hay không Y/N';
          public          postgres    false    204            �           0    0 $   COLUMN "FEE_CATEGORY"."LAST_UPDATED"    COMMENT     c   COMMENT ON COLUMN public."FEE_CATEGORY"."LAST_UPDATED" IS 'Thời gian cập nhật cuối cùng';
          public          postgres    false    204            �            1259    17139    FEE_LIST    TABLE     \  CREATE TABLE public."FEE_LIST" (
    "FEE_ID" character varying(50) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "FEE_TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public."FEE_LIST";
       public         heap    postgres    false    3            �           0    0    TABLE "FEE_LIST"    COMMENT     E   COMMENT ON TABLE public."FEE_LIST" IS 'Danh sách các loại phí';
          public          postgres    false    209            �            1259    17365    FEE_SETTING    TABLE     �  CREATE TABLE public."FEE_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "MARKETID" character varying(50),
    "STOCK_TYPE" character varying(50),
    "CHANNEL" character varying(50),
    "MAX_VALUES" numeric(20,0),
    "MIN_VALUES" numeric(20,0),
    "VALUES" numeric(20,4),
    "ACTIVE_YN" "char",
    "RULES" character varying(50),
    "FEE_ID" character varying(50)
);
 !   DROP TABLE public."FEE_SETTING";
       public         heap    postgres    false    3            �            1259    17153 	   LOAN_LIST    TABLE     _  CREATE TABLE public."LOAN_LIST" (
    "LOAN_ID" character varying(50) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "LOAN_TYPE" character varying(50),
    "ACTIVE_YN" "char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public."LOAN_LIST";
       public         heap    postgres    false    3            �            1259    17161    LOAN_SETTING    TABLE     %  CREATE TABLE public."LOAN_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "INTEREST_RATE" integer,
    "ACTIVE_YN" "char",
    "LOAN_TERM" integer,
    "DIVISOR" integer,
    "LOAN_ID" character varying(50)
);
 "   DROP TABLE public."LOAN_SETTING";
       public         heap    postgres    false    3            �            1259    17164    MARGIN_SETTING    TABLE     �  CREATE TABLE public."MARGIN_SETTING" (
    "MARGIN_ID" character varying(20) NOT NULL,
    "MARGIN_DESC" character varying(200),
    "MARGIN_RATIO" numeric(20,0) DEFAULT 0,
    "MARGIN_LIMIT" numeric(20,0) DEFAULT 0,
    "MARGIN_CALL_RATE" numeric(20,0) DEFAULT 0,
    "MARGIN_FORCE_RATE" numeric(20,0) DEFAULT 0,
    "ACTIVE_YN" "char" DEFAULT 'Y'::"char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 $   DROP TABLE public."MARGIN_SETTING";
       public         heap    postgres    false    3            �            1259    17414    ORDER    TABLE     �  CREATE TABLE public."ORDER" (
    "SYS_ORDER_NO" bigint NOT NULL,
    "EXCHG_CD" character varying(20),
    "CHANNEL" character varying(10),
    "ORDER_STATUS" character varying(10),
    "STOCK_CD" character varying(20),
    "ORDER_PRICE" integer,
    "ORDER_QTY" integer,
    "EXEC_QTY" integer,
    "BID_ASK_TYPE" character varying(10),
    "ORDER_SUBMIT_DT" timestamp with time zone,
    "BRANCH_NO" integer,
    "EXCHG_ORDER_TYPE" character varying(10),
    "CUST_ID" character varying(50),
    "SHORTSELL_FLG" character(1),
    "PARENT_ORDER_NO" bigint,
    "TRADE_ID" character varying(50),
    "BROKER_ID" character varying(50),
    "EXCHG_SUBMIT_DT" timestamp with time zone,
    "GOOD_TILL_DATE" date,
    "HOLD_STATUS" character varying(10),
    "DMA_FLAG" character(1),
    "PRIORITY_FLG" character(1),
    "FREE_PCT" integer,
    "LAST_UPD_DT" timestamp with time zone,
    "TRADE_DATE" date
);
    DROP TABLE public."ORDER";
       public         heap    postgres    false    3            �           0    0    COLUMN "ORDER"."SYS_ORDER_NO"    COMMENT     N   COMMENT ON COLUMN public."ORDER"."SYS_ORDER_NO" IS 'Số thứ tự lệnh ';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."EXCHG_CD"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."EXCHG_CD" IS 'Sàn giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."CHANNEL"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."CHANNEL" IS 'Kênh giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_STATUS"    COMMENT     K   COMMENT ON COLUMN public."ORDER"."ORDER_STATUS" IS 'Trạng thái lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."STOCK_CD"    COMMENT     E   COMMENT ON COLUMN public."ORDER"."STOCK_CD" IS 'Mã chứng khoán';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_PRICE"    COMMENT     A   COMMENT ON COLUMN public."ORDER"."ORDER_PRICE" IS 'Gía đặt';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."ORDER_QTY"    COMMENT     J   COMMENT ON COLUMN public."ORDER"."ORDER_QTY" IS 'Khối lượng đặt';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."EXEC_QTY"    COMMENT     H   COMMENT ON COLUMN public."ORDER"."EXEC_QTY" IS 'Khối lương khớp';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BID_ASK_TYPE"    COMMENT     N   COMMENT ON COLUMN public."ORDER"."BID_ASK_TYPE" IS 'Loại lệnh: Mua/bán';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."ORDER_SUBMIT_DT"    COMMENT     S   COMMENT ON COLUMN public."ORDER"."ORDER_SUBMIT_DT" IS 'Thời gian đặt lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BRANCH_NO"    COMMENT     >   COMMENT ON COLUMN public."ORDER"."BRANCH_NO" IS 'Chi nhánh';
          public          postgres    false    217            �           0    0 !   COLUMN "ORDER"."EXCHG_ORDER_TYPE"    COMMENT     j   COMMENT ON COLUMN public."ORDER"."EXCHG_ORDER_TYPE" IS 'Loại lệnh trên sàn: ATO/ATC/LO/MP/MAK/MOK';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."CUST_ID"    COMMENT     B   COMMENT ON COLUMN public."ORDER"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."SHORTSELL_FLG"    COMMENT     T   COMMENT ON COLUMN public."ORDER"."SHORTSELL_FLG" IS 'Lệnh bị shortsell -> Y/N';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."PARENT_ORDER_NO"    COMMENT     D   COMMENT ON COLUMN public."ORDER"."PARENT_ORDER_NO" IS 'Lệnh cha';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."TRADE_ID"    COMMENT     L   COMMENT ON COLUMN public."ORDER"."TRADE_ID" IS 'Nhân viên đặt lệnh';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."BROKER_ID"    COMMENT     J   COMMENT ON COLUMN public."ORDER"."BROKER_ID" IS 'Môi giới quản lý';
          public          postgres    false    217            �           0    0     COLUMN "ORDER"."EXCHG_SUBMIT_DT"    COMMENT     O   COMMENT ON COLUMN public."ORDER"."EXCHG_SUBMIT_DT" IS 'Thời gian lên sàn';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."GOOD_TILL_DATE"    COMMENT     m   COMMENT ON COLUMN public."ORDER"."GOOD_TILL_DATE" IS 'Ngày giao dịch - Dùng cho đặt lệnh trước';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."HOLD_STATUS"    COMMENT     g   COMMENT ON COLUMN public."ORDER"."HOLD_STATUS" IS 'Tình trạng phong tỏa tiền bên ngân hàng';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."DMA_FLAG"    COMMENT     [   COMMENT ON COLUMN public."ORDER"."DMA_FLAG" IS 'Cờ DMA: giao dịch online hay offline';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."PRIORITY_FLG"    COMMENT     G   COMMENT ON COLUMN public."ORDER"."PRIORITY_FLG" IS 'Lệnh ưu tiên';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."FREE_PCT"    COMMENT     C   COMMENT ON COLUMN public."ORDER"."FREE_PCT" IS 'Phí giao dịch';
          public          postgres    false    217            �           0    0    COLUMN "ORDER"."LAST_UPD_DT"    COMMENT     [   COMMENT ON COLUMN public."ORDER"."LAST_UPD_DT" IS 'Thời gian cập nhật cuối cùng';
          public          postgres    false    217            �            1259    17419    ORDER_DETAIL    TABLE     e  CREATE TABLE public."ORDER_DETAIL" (
    "SYS_ORDER_NO" bigint NOT NULL,
    "ORDER_SUB_NO" integer NOT NULL,
    "EXCHG_CD" character varying(20),
    "TRADE_DATE" date,
    "SESSION_ID" integer,
    "ORDER_QTY" integer,
    "ORDER_PRICE" integer,
    "STATUS" character varying(20),
    "CREATE_DATE" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."ORDER_DETAIL";
       public         heap    postgres    false    3            �           0    0 $   COLUMN "ORDER_DETAIL"."SYS_ORDER_NO"    COMMENT     o   COMMENT ON COLUMN public."ORDER_DETAIL"."SYS_ORDER_NO" IS 'Số thứ tự lệnh-> ứng với bảng ORDER';
          public          postgres    false    218            �           0    0 $   COLUMN "ORDER_DETAIL"."ORDER_SUB_NO"    COMMENT     �   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_SUB_NO" IS 'Số thứ tự con của từng lệnh: bắt đầu từ 1 đến n đối với từng lệnh';
          public          postgres    false    218            �           0    0     COLUMN "ORDER_DETAIL"."EXCHG_CD"    COMMENT     J   COMMENT ON COLUMN public."ORDER_DETAIL"."EXCHG_CD" IS 'Sàn giao dịch';
          public          postgres    false    218            �           0    0 "   COLUMN "ORDER_DETAIL"."TRADE_DATE"    COMMENT     M   COMMENT ON COLUMN public."ORDER_DETAIL"."TRADE_DATE" IS 'Ngày giao dịch';
          public          postgres    false    218            �           0    0 "   COLUMN "ORDER_DETAIL"."SESSION_ID"    COMMENT     N   COMMENT ON COLUMN public."ORDER_DETAIL"."SESSION_ID" IS 'Phiên giao dịch';
          public          postgres    false    218            �           0    0 !   COLUMN "ORDER_DETAIL"."ORDER_QTY"    COMMENT     J   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_QTY" IS 'Khối lượng';
          public          postgres    false    218            �           0    0 #   COLUMN "ORDER_DETAIL"."ORDER_PRICE"    COMMENT     A   COMMENT ON COLUMN public."ORDER_DETAIL"."ORDER_PRICE" IS 'Giá';
          public          postgres    false    218            �           0    0    COLUMN "ORDER_DETAIL"."STATUS"    COMMENT     L   COMMENT ON COLUMN public."ORDER_DETAIL"."STATUS" IS 'Trạng thái lệnh';
          public          postgres    false    218            �           0    0 #   COLUMN "ORDER_DETAIL"."CREATE_DATE"    COMMENT     Z   COMMENT ON COLUMN public."ORDER_DETAIL"."CREATE_DATE" IS 'Thời gian tạo dữ liệu';
          public          postgres    false    218            �            1259    17534    ORDER_SQ    SEQUENCE     r   CREATE SEQUENCE public."ORDER_SQ"
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE public."ORDER_SQ";
       public          postgres    false    3            �            1259    17396    PRODUCT_FEE    TABLE     7  CREATE TABLE public."PRODUCT_FEE" (
    "PRODUCT_ID" character varying(50) NOT NULL,
    "FEE_ID" character varying(200) NOT NULL,
    "ACTIVE_YN" "char",
    "EFFECT_DATE" date,
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 !   DROP TABLE public."PRODUCT_FEE";
       public         heap    postgres    false    3            �            1259    17180    PRODUCT_LIST    TABLE     V  CREATE TABLE public."PRODUCT_LIST" (
    "PRODUCT_ID" character varying(20) NOT NULL,
    "DESC_VN" character varying(200),
    "DESC_EN" character varying(200),
    "ACTIVE_YN" "char",
    "EFFECT_DATE" date,
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 "   DROP TABLE public."PRODUCT_LIST";
       public         heap    postgres    false    3            �            1259    17185    PRODUCT_SETTING    TABLE     9  CREATE TABLE public."PRODUCT_SETTING" (
    "PRODUCT_ID" character varying(20) NOT NULL,
    "MARGIN_ID" character varying(20) NOT NULL,
    "ACTIVE_YN" "char" DEFAULT 'Y'::"char",
    "CREATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP,
    "UPDATE_DATE" time with time zone DEFAULT CURRENT_TIMESTAMP
);
 %   DROP TABLE public."PRODUCT_SETTING";
       public         heap    postgres    false    3            �            1259    16476 
   STOCK_INFO    TABLE     o  CREATE TABLE public."STOCK_INFO" (
    "EXCHG_CD" character varying(50)[] NOT NULL,
    "STOCK_NO" character varying(50)[] NOT NULL,
    "STOCK_TYPE" character varying(50)[],
    "STOCK_STATUS" character varying(200)[],
    "STOCK_NAME" character varying(200)[],
    "STOCK_NAMEEN" character varying(200)[],
    "LOT_SIZE" integer,
    "START_TRADE_DT" date,
    "END_TRADE_DT" date,
    "CLOSE_PRICE" numeric,
    "LAST_CLOSE_PRICE" numeric,
    "FLOOR_PRICE" numeric,
    "CEILING_PRICE" numeric,
    "TOTAL_ROOM" numeric,
    "CURRENT_ROOM" numeric,
    "OFFICAL_CODE" character varying(20)[],
    "ISSUED_SHARE" numeric,
    "LISTED_SHARE" numeric,
    "MARGIN_CAP_PRICE" numeric,
    "ISIN_CODE" character varying(20)[],
    "SEDOL_CODE" character varying(20)[],
    "UPD_SRC" character varying(20)[],
    "UPD_DT" timestamp without time zone,
    "MARGIN_RATIO" integer
);
     DROP TABLE public."STOCK_INFO";
       public         heap    postgres    false    3            �           0    0    COLUMN "STOCK_INFO"."EXCHG_CD"    COMMENT     K   COMMENT ON COLUMN public."STOCK_INFO"."EXCHG_CD" IS 'Sàn chứng khoán';
          public          postgres    false    202            �           0    0    COLUMN "STOCK_INFO"."STOCK_NO"    COMMENT     J   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NO" IS 'Mã chứng khoán';
          public          postgres    false    202            �           0    0     COLUMN "STOCK_INFO"."STOCK_TYPE"    COMMENT     v   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_TYPE" IS 'Loại: chứng khoán, chứng chỉ quỹ, phái sinh ... ';
          public          postgres    false    202            �           0    0 "   COLUMN "STOCK_INFO"."STOCK_STATUS"    COMMENT     �   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_STATUS" IS 'Trạng thái chứng khoán: bình thường, hạn chế giao dịch, hủy niêm yết ...';
          public          postgres    false    202            �           0    0     COLUMN "STOCK_INFO"."STOCK_NAME"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NAME" IS 'Tên tiếng việt của chứng khoán';
          public          postgres    false    202                        0    0 "   COLUMN "STOCK_INFO"."STOCK_NAMEEN"    COMMENT     L   COMMENT ON COLUMN public."STOCK_INFO"."STOCK_NAMEEN" IS 'Tên tiếng anh';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."LOT_SIZE"    COMMENT     w   COMMENT ON COLUMN public."STOCK_INFO"."LOT_SIZE" IS 'Khối lượng đặt tối thiểu: HSX: 10cp, HNX\UPCOM: 100';
          public          postgres    false    202                       0    0 $   COLUMN "STOCK_INFO"."START_TRADE_DT"    COMMENT     \   COMMENT ON COLUMN public."STOCK_INFO"."START_TRADE_DT" IS 'Ngày giao dịch đầu tiên';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."END_TRADE_DT"    COMMENT     Z   COMMENT ON COLUMN public."STOCK_INFO"."END_TRADE_DT" IS 'Ngày giao dịch cuối cùng';
          public          postgres    false    202                       0    0 !   COLUMN "STOCK_INFO"."CLOSE_PRICE"    COMMENT     U   COMMENT ON COLUMN public."STOCK_INFO"."CLOSE_PRICE" IS 'Giá đóng cửa hôm nay';
          public          postgres    false    202                       0    0 &   COLUMN "STOCK_INFO"."LAST_CLOSE_PRICE"    COMMENT     _   COMMENT ON COLUMN public."STOCK_INFO"."LAST_CLOSE_PRICE" IS 'Giá đóng cửa hôm trước';
          public          postgres    false    202                       0    0 !   COLUMN "STOCK_INFO"."FLOOR_PRICE"    COMMENT     D   COMMENT ON COLUMN public."STOCK_INFO"."FLOOR_PRICE" IS 'Giá sàn';
          public          postgres    false    202                       0    0 #   COLUMN "STOCK_INFO"."CEILING_PRICE"    COMMENT     H   COMMENT ON COLUMN public."STOCK_INFO"."CEILING_PRICE" IS 'Giá trần';
          public          postgres    false    202                       0    0     COLUMN "STOCK_INFO"."TOTAL_ROOM"    COMMENT     T   COMMENT ON COLUMN public."STOCK_INFO"."TOTAL_ROOM" IS 'Tổng room nước ngoài';
          public          postgres    false    202            	           0    0 "   COLUMN "STOCK_INFO"."CURRENT_ROOM"    COMMENT     Z   COMMENT ON COLUMN public."STOCK_INFO"."CURRENT_ROOM" IS 'Room nước ngoài còn lại';
          public          postgres    false    202            
           0    0 "   COLUMN "STOCK_INFO"."OFFICAL_CODE"    COMMENT     X   COMMENT ON COLUMN public."STOCK_INFO"."OFFICAL_CODE" IS 'ID chứng khoán của sở';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."ISSUED_SHARE"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."ISSUED_SHARE" IS 'Số lượng cổ phiếu phát hành';
          public          postgres    false    202                       0    0 "   COLUMN "STOCK_INFO"."LISTED_SHARE"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."LISTED_SHARE" IS 'Số lượng cổ phiếu niêm yết';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."ISIN_CODE"    COMMENT     A   COMMENT ON COLUMN public."STOCK_INFO"."ISIN_CODE" IS 'Mã ISIN';
          public          postgres    false    202                       0    0     COLUMN "STOCK_INFO"."SEDOL_CODE"    COMMENT     C   COMMENT ON COLUMN public."STOCK_INFO"."SEDOL_CODE" IS 'Mã SEDOL';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."UPD_SRC"    COMMENT     b   COMMENT ON COLUMN public."STOCK_INFO"."UPD_SRC" IS 'Nguồn cập nhật thông tin dữ liệu';
          public          postgres    false    202                       0    0    COLUMN "STOCK_INFO"."UPD_DT"    COMMENT     ^   COMMENT ON COLUMN public."STOCK_INFO"."UPD_DT" IS 'Thời gian cập thông tin dữ liệu';
          public          postgres    false    202            �            1259    17454    TEST_FEE_SETTING    TABLE       CREATE TABLE public."TEST_FEE_SETTING" (
    "NAME_ID" character varying(50) NOT NULL,
    "DESC" character varying(200),
    "UNITS" character varying(50),
    "MARKETID" character varying(50),
    "STOCK_TYPE" character varying(50),
    "CHANNEL" character varying(50),
    "MAX_VALUES" numeric(20,0),
    "MIN_VALUES" numeric(20,0),
    "VALUES" numeric(20,4),
    "ACTIVE_YN" "char",
    "TYPE" character varying(50),
    "FEE_ID" character varying(50),
    "PRIORITY" integer,
    "RULES" character varying(50)
);
 &   DROP TABLE public."TEST_FEE_SETTING";
       public         heap    postgres    false    3            �            1259    17099 	   USER_AUTH    TABLE       CREATE TABLE public."USER_AUTH" (
    "LOGIN_UID" character varying(50) NOT NULL,
    "CHANNEL" character varying(20) NOT NULL,
    "CUST_ID" character varying(50) NOT NULL,
    "LOGIN_PWD" character varying(200),
    "TRADE_PWD" character varying(200),
    "LOGIN_RETRY" integer,
    "LAST_LOGIN_DT" timestamp without time zone,
    "LATEST_LOGIN_DT" timestamp without time zone
);
    DROP TABLE public."USER_AUTH";
       public         heap    postgres    false    3                       0    0    COLUMN "USER_AUTH"."LOGIN_UID"    COMMENT     J   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_UID" IS 'Tên đăng nhập';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."CHANNEL"    COMMENT     U   COMMENT ON COLUMN public."USER_AUTH"."CHANNEL" IS 'Kênh đăng nhập: Mobile/Web';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."CUST_ID"    COMMENT     F   COMMENT ON COLUMN public."USER_AUTH"."CUST_ID" IS 'Mã khách hàng';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."LOGIN_PWD"    COMMENT     R   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_PWD" IS 'Mật khẩu đăng nhập';
          public          postgres    false    207                       0    0    COLUMN "USER_AUTH"."TRADE_PWD"    COMMENT     L   COMMENT ON COLUMN public."USER_AUTH"."TRADE_PWD" IS 'Mật khẩu trading';
          public          postgres    false    207                       0    0     COLUMN "USER_AUTH"."LOGIN_RETRY"    COMMENT     W   COMMENT ON COLUMN public."USER_AUTH"."LOGIN_RETRY" IS 'Số lần đăng nhập fail';
          public          postgres    false    207                       0    0 "   COLUMN "USER_AUTH"."LAST_LOGIN_DT"    COMMENT     b   COMMENT ON COLUMN public."USER_AUTH"."LAST_LOGIN_DT" IS 'Thời gian đăng nhập gần nhất';
          public          postgres    false    207                       0    0 $   COLUMN "USER_AUTH"."LATEST_LOGIN_DT"    COMMENT     d   COMMENT ON COLUMN public."USER_AUTH"."LATEST_LOGIN_DT" IS 'Thời gian đăng nhập lần cuối';
          public          postgres    false    207            �            1259    17130    client_cash_bal    TABLE     �  CREATE TABLE public.client_cash_bal (
    clientid character varying(50) NOT NULL,
    tradedate date NOT NULL,
    opencashbal numeric,
    cashdeposit numeric,
    cashonhold numeric,
    buyamt_unmatch numeric,
    sellamt_unmatch numeric,
    sellamt_t1 numeric,
    sellamt_t2 numeric,
    buyamt_t1 numeric,
    buyamt_t2 numeric,
    buyamt_t numeric,
    sellamt_t numeric,
    debitinterest numeric,
    credit_interest numeric,
    others_free numeric,
    cia_used_t numeric,
    cia_used_t1 numeric,
    cia_used_t2 numeric,
    pending_cia numeric,
    debitamt numeric,
    pre_loan numeric,
    expected_dividend numeric,
    margin_dividend numeric,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 #   DROP TABLE public.client_cash_bal;
       public         heap    postgres    false    3                       0    0     COLUMN client_cash_bal.tradedate    COMMENT     K   COMMENT ON COLUMN public.client_cash_bal.tradedate IS 'Ngày làm việc';
          public          postgres    false    208                       0    0 "   COLUMN client_cash_bal.opencashbal    COMMENT     Q   COMMENT ON COLUMN public.client_cash_bal.opencashbal IS 'Số dư đầu ngày';
          public          postgres    false    208                       0    0 "   COLUMN client_cash_bal.cashdeposit    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.cashdeposit IS 'Số tiền nộp vào';
          public          postgres    false    208                       0    0 !   COLUMN client_cash_bal.cashonhold    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.cashonhold IS 'Số tiền phong tỏa';
          public          postgres    false    208                       0    0 %   COLUMN client_cash_bal.buyamt_unmatch    COMMENT     o   COMMENT ON COLUMN public.client_cash_bal.buyamt_unmatch IS 'Lệnh mua trong ngày chưa khớp (gồm phí)';
          public          postgres    false    208                       0    0 &   COLUMN client_cash_bal.sellamt_unmatch    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.sellamt_unmatch IS 'Lệnh bán trong ngày chưa khớp (đã trừ thuế, phí GD)';
          public          postgres    false    208                       0    0 !   COLUMN client_cash_bal.sellamt_t1    COMMENT     x   COMMENT ON COLUMN public.client_cash_bal.sellamt_t1 IS 'Giá trị bán khớp ngày T+1 (đã trừ thuế, phí GD)';
          public          postgres    false    208                        0    0 !   COLUMN client_cash_bal.sellamt_t2    COMMENT     x   COMMENT ON COLUMN public.client_cash_bal.sellamt_t2 IS 'Giá trị bán khớp ngày T+2 (đã trừ thuế, phí GD)';
          public          postgres    false    208            !           0    0     COLUMN client_cash_bal.buyamt_t1    COMMENT     f   COMMENT ON COLUMN public.client_cash_bal.buyamt_t1 IS 'Giá trị mua khớp ngày T+1 (gồm phí)';
          public          postgres    false    208            "           0    0     COLUMN client_cash_bal.buyamt_t2    COMMENT     f   COMMENT ON COLUMN public.client_cash_bal.buyamt_t2 IS 'Giá trị mua khớp ngày T+2 (gồm phí)';
          public          postgres    false    208            #           0    0    COLUMN client_cash_bal.buyamt_t    COMMENT     g   COMMENT ON COLUMN public.client_cash_bal.buyamt_t IS 'Giá trị mua khớp trong ngày (gồm phí)';
          public          postgres    false    208            $           0    0     COLUMN client_cash_bal.sellamt_t    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.sellamt_t IS 'Giá trị bán khớp trong ngày (đã trừ thuế, phí giao dịch)';
          public          postgres    false    208            %           0    0 $   COLUMN client_cash_bal.debitinterest    COMMENT     R   COMMENT ON COLUMN public.client_cash_bal.debitinterest IS 'Lãi vay tạm tính';
          public          postgres    false    208            &           0    0 &   COLUMN client_cash_bal.credit_interest    COMMENT     Z   COMMENT ON COLUMN public.client_cash_bal.credit_interest IS 'Lãi tiền gởi dự thu';
          public          postgres    false    208            '           0    0 "   COLUMN client_cash_bal.others_free    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.others_free IS 'Các khoản phí khác: phí lưu ký, phí chuyển khoản chứng khoán …';
          public          postgres    false    208            (           0    0 !   COLUMN client_cash_bal.cia_used_t    COMMENT     [   COMMENT ON COLUMN public.client_cash_bal.cia_used_t IS 'Tiền ứng sử dụng ngày T';
          public          postgres    false    208            )           0    0 "   COLUMN client_cash_bal.cia_used_t1    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.cia_used_t1 IS 'Tiền ứng sử dụng ngày T-1';
          public          postgres    false    208            *           0    0 "   COLUMN client_cash_bal.cia_used_t2    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.cia_used_t2 IS 'Tiền ứng sử dụng ngày T-2';
          public          postgres    false    208            +           0    0 "   COLUMN client_cash_bal.pending_cia    COMMENT     \   COMMENT ON COLUMN public.client_cash_bal.pending_cia IS 'Tiền ứng đang chờ duyệt';
          public          postgres    false    208            ,           0    0    COLUMN client_cash_bal.debitamt    COMMENT     S   COMMENT ON COLUMN public.client_cash_bal.debitamt IS 'Dư nợ đã giải ngân';
          public          postgres    false    208            -           0    0    COLUMN client_cash_bal.pre_loan    COMMENT     �   COMMENT ON COLUMN public.client_cash_bal.pre_loan IS 'Dư nợ dự kiến giải ngân - từ deal mua chưa đến hạn thành toán';
          public          postgres    false    208            .           0    0 (   COLUMN client_cash_bal.expected_dividend    COMMENT     ^   COMMENT ON COLUMN public.client_cash_bal.expected_dividend IS 'Tiền cổ tức chờ về';
          public          postgres    false    208            /           0    0 &   COLUMN client_cash_bal.margin_dividend    COMMENT     }   COMMENT ON COLUMN public.client_cash_bal.margin_dividend IS 'Tiền cổ tức được tính làm tài sản đảm bảo';
          public          postgres    false    208            �            1259    16870    client_stock_bal    TABLE     M  CREATE TABLE public.client_stock_bal (
    clientid character varying(50) NOT NULL,
    tradedate date NOT NULL,
    marketid character varying(20),
    stock_symbol character varying(20),
    sellable integer,
    buy_t integer,
    bought_t integer,
    sell_t integer,
    sold_t integer,
    buy_t1 integer,
    sell_t1 integer,
    buy_t2 integer,
    sell_t2 integer,
    hold_for_block integer,
    hold_for_temp integer,
    hold_for_trade integer,
    dep_with integer,
    on_hand integer,
    bonus integer,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 $   DROP TABLE public.client_stock_bal;
       public         heap    postgres    false    3            0           0    0     COLUMN client_stock_bal.marketid    COMMENT     J   COMMENT ON COLUMN public.client_stock_bal.marketid IS 'Sàn giao dịch';
          public          postgres    false    203            1           0    0 $   COLUMN client_stock_bal.stock_symbol    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.stock_symbol IS 'Mã chứng khoán';
          public          postgres    false    203            2           0    0     COLUMN client_stock_bal.sellable    COMMENT     c   COMMENT ON COLUMN public.client_stock_bal.sellable IS 'Số lượng cổ phiếu có thể bán';
          public          postgres    false    203            3           0    0    COLUMN client_stock_bal.buy_t    COMMENT     ~   COMMENT ON COLUMN public.client_stock_bal.buy_t IS 'Số lượng cổ phiếu đặt mua trong ngày (khớp/chưa khớp)';
          public          postgres    false    203            4           0    0     COLUMN client_stock_bal.bought_t    COMMENT     U   COMMENT ON COLUMN public.client_stock_bal.bought_t IS 'SLCP Khớp mua trong ngày';
          public          postgres    false    203            5           0    0    COLUMN client_stock_bal.sell_t    COMMENT     j   COMMENT ON COLUMN public.client_stock_bal.sell_t IS 'SLCP đặt bán trong ngày (Khớp/Chưa khớp)';
          public          postgres    false    203            6           0    0    COLUMN client_stock_bal.sold_t    COMMENT     S   COMMENT ON COLUMN public.client_stock_bal.sold_t IS 'SLCP Khớp mua trong ngày';
          public          postgres    false    203            7           0    0    COLUMN client_stock_bal.buy_t1    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.buy_t1 IS 'SLCP Khớp mua ngày T1';
          public          postgres    false    203            8           0    0    COLUMN client_stock_bal.sell_t1    COMMENT     R   COMMENT ON COLUMN public.client_stock_bal.sell_t1 IS 'SLCP Khớp bán ngày T1';
          public          postgres    false    203            9           0    0    COLUMN client_stock_bal.buy_t2    COMMENT     P   COMMENT ON COLUMN public.client_stock_bal.buy_t2 IS 'SLCP Khớp mua ngày T2';
          public          postgres    false    203            :           0    0    COLUMN client_stock_bal.sell_t2    COMMENT     R   COMMENT ON COLUMN public.client_stock_bal.sell_t2 IS 'SLCP Khớp bán ngày T2';
          public          postgres    false    203            ;           0    0 &   COLUMN client_stock_bal.hold_for_block    COMMENT     V   COMMENT ON COLUMN public.client_stock_bal.hold_for_block IS 'SLCP tạm phong tỏa';
          public          postgres    false    203            <           0    0 %   COLUMN client_stock_bal.hold_for_temp    COMMENT        COMMENT ON COLUMN public.client_stock_bal.hold_for_temp IS 'SLCP phong tỏa (Ví dụ: hạn chế chuyển nhượng, …)';
          public          postgres    false    203            =           0    0 &   COLUMN client_stock_bal.hold_for_trade    COMMENT     W   COMMENT ON COLUMN public.client_stock_bal.hold_for_trade IS 'SLCP chờ giao dịch.';
          public          postgres    false    203            >           0    0     COLUMN client_stock_bal.dep_with    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.dep_with IS 'SLCP Nộp (nhận chuyển khoản) trong ngày
SLCP Rút (chuyển khoản) trong ngày nếu là số âm';
          public          postgres    false    203            ?           0    0    COLUMN client_stock_bal.on_hand    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.on_hand IS 'SLCP đang có trong tài khoản.
 Gồm tất cả các loại cp (kể cả cp BÁN chờ thanh toán), ngoại
 trừ: cp MUA chờ nhận thanh toán, cp Quyền chưa lưu ký
 (Bonus)';
          public          postgres    false    203            @           0    0    COLUMN client_stock_bal.bonus    COMMENT     �   COMMENT ON COLUMN public.client_stock_bal.bonus IS 'Cp thưởng, Cổ tức bằng cp, Quyền mua đã đăng ký …chưa lưu ký.';
          public          postgres    false    203            �            1259    16931    interest_category    TABLE     5  CREATE TABLE public.interest_category (
    id character varying(50) NOT NULL,
    desc_vn character varying(200),
    desc_en character varying(200),
    effective_date date,
    "TYPE" character varying(50),
    active_yn character(1),
    last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
 %   DROP TABLE public.interest_category;
       public         heap    postgres    false    3            �          0    17090    CUSTOMER_INFO 
   TABLE DATA           l  COPY public."CUSTOMER_INFO" ("CUST_ID", "CUST_NAME", "TAX_ID", "ID_ISSUE_DATE", "ID_ISSUE_PLACE", "ID_TYPE", "BIRTH_DATE", "SEX", "MOBILE_PHONE", "FAX_NO", "ADDRESS_1", "ADDRESS_2", "NATIONALITY", "CUST_TYPE", "ACCT_TYPE", "BANK_ACCT", "BRANCH_NO", "ACCT_STATUS", "BROKER_ID", "OPEN_DATE", "CLOSE_DATE", "UPD_DATE", "OPEN_UID", "CLOSE_UID", "UPD_UID") FROM stdin;
    public          postgres    false    206            �          0    16922    FEE_CATEGORY 
   TABLE DATA              COPY public."FEE_CATEGORY" ("FEE_ID", "DESC_EN", "DESC_VN", "EFFECTIVE_DATE", "TYPE", "ACTIVE_YN", "LAST_UPDATED") FROM stdin;
    public          postgres    false    204           �          0    17139    FEE_LIST 
   TABLE DATA           {   COPY public."FEE_LIST" ("FEE_ID", "DESC_VN", "DESC_EN", "FEE_TYPE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    209   �        �          0    17365    FEE_SETTING 
   TABLE DATA           �   COPY public."FEE_SETTING" ("NAME_ID", "DESC", "UNITS", "MARKETID", "STOCK_TYPE", "CHANNEL", "MAX_VALUES", "MIN_VALUES", "VALUES", "ACTIVE_YN", "RULES", "FEE_ID") FROM stdin;
    public          postgres    false    215   1       �          0    17153 	   LOAN_LIST 
   TABLE DATA           ~   COPY public."LOAN_LIST" ("LOAN_ID", "DESC_VN", "DESC_EN", "LOAN_TYPE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    210   �        �          0    17161    LOAN_SETTING 
   TABLE DATA           �   COPY public."LOAN_SETTING" ("NAME_ID", "DESC", "UNITS", "INTEREST_RATE", "ACTIVE_YN", "LOAN_TERM", "DIVISOR", "LOAN_ID") FROM stdin;
    public          postgres    false    211   �        �          0    17164    MARGIN_SETTING 
   TABLE DATA           �   COPY public."MARGIN_SETTING" ("MARGIN_ID", "MARGIN_DESC", "MARGIN_RATIO", "MARGIN_LIMIT", "MARGIN_CALL_RATE", "MARGIN_FORCE_RATE", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    212   x        �          0    17414    ORDER 
   TABLE DATA           �  COPY public."ORDER" ("SYS_ORDER_NO", "EXCHG_CD", "CHANNEL", "ORDER_STATUS", "STOCK_CD", "ORDER_PRICE", "ORDER_QTY", "EXEC_QTY", "BID_ASK_TYPE", "ORDER_SUBMIT_DT", "BRANCH_NO", "EXCHG_ORDER_TYPE", "CUST_ID", "SHORTSELL_FLG", "PARENT_ORDER_NO", "TRADE_ID", "BROKER_ID", "EXCHG_SUBMIT_DT", "GOOD_TILL_DATE", "HOLD_STATUS", "DMA_FLAG", "PRIORITY_FLG", "FREE_PCT", "LAST_UPD_DT", "TRADE_DATE") FROM stdin;
    public          postgres    false    217   �        �          0    17419    ORDER_DETAIL 
   TABLE DATA           �   COPY public."ORDER_DETAIL" ("SYS_ORDER_NO", "ORDER_SUB_NO", "EXCHG_CD", "TRADE_DATE", "SESSION_ID", "ORDER_QTY", "ORDER_PRICE", "STATUS", "CREATE_DATE") FROM stdin;
    public          postgres    false    218           �          0    17396    PRODUCT_FEE 
   TABLE DATA           y   COPY public."PRODUCT_FEE" ("PRODUCT_ID", "FEE_ID", "ACTIVE_YN", "EFFECT_DATE", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    216           �          0    17180    PRODUCT_LIST 
   TABLE DATA           �   COPY public."PRODUCT_LIST" ("PRODUCT_ID", "DESC_VN", "DESC_EN", "ACTIVE_YN", "EFFECT_DATE", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    213   l        �          0    17185    PRODUCT_SETTING 
   TABLE DATA           q   COPY public."PRODUCT_SETTING" ("PRODUCT_ID", "MARGIN_ID", "ACTIVE_YN", "CREATE_DATE", "UPDATE_DATE") FROM stdin;
    public          postgres    false    214   �        �          0    16476 
   STOCK_INFO 
   TABLE DATA           �  COPY public."STOCK_INFO" ("EXCHG_CD", "STOCK_NO", "STOCK_TYPE", "STOCK_STATUS", "STOCK_NAME", "STOCK_NAMEEN", "LOT_SIZE", "START_TRADE_DT", "END_TRADE_DT", "CLOSE_PRICE", "LAST_CLOSE_PRICE", "FLOOR_PRICE", "CEILING_PRICE", "TOTAL_ROOM", "CURRENT_ROOM", "OFFICAL_CODE", "ISSUED_SHARE", "LISTED_SHARE", "MARGIN_CAP_PRICE", "ISIN_CODE", "SEDOL_CODE", "UPD_SRC", "UPD_DT", "MARGIN_RATIO") FROM stdin;
    public          postgres    false    202   Q        �          0    17454    TEST_FEE_SETTING 
   TABLE DATA           �   COPY public."TEST_FEE_SETTING" ("NAME_ID", "DESC", "UNITS", "MARKETID", "STOCK_TYPE", "CHANNEL", "MAX_VALUES", "MIN_VALUES", "VALUES", "ACTIVE_YN", "TYPE", "FEE_ID", "PRIORITY", "RULES") FROM stdin;
    public          postgres    false    219           �          0    17099 	   USER_AUTH 
   TABLE DATA           �   COPY public."USER_AUTH" ("LOGIN_UID", "CHANNEL", "CUST_ID", "LOGIN_PWD", "TRADE_PWD", "LOGIN_RETRY", "LAST_LOGIN_DT", "LATEST_LOGIN_DT") FROM stdin;
    public          postgres    false    207   1       �          0    17130    client_cash_bal 
   TABLE DATA           m  COPY public.client_cash_bal (clientid, tradedate, opencashbal, cashdeposit, cashonhold, buyamt_unmatch, sellamt_unmatch, sellamt_t1, sellamt_t2, buyamt_t1, buyamt_t2, buyamt_t, sellamt_t, debitinterest, credit_interest, others_free, cia_used_t, cia_used_t1, cia_used_t2, pending_cia, debitamt, pre_loan, expected_dividend, margin_dividend, update_time) FROM stdin;
    public          postgres    false    208   9        �          0    16870    client_stock_bal 
   TABLE DATA           �   COPY public.client_stock_bal (clientid, tradedate, marketid, stock_symbol, sellable, buy_t, bought_t, sell_t, sold_t, buy_t1, sell_t1, buy_t2, sell_t2, hold_for_block, hold_for_temp, hold_for_trade, dep_with, on_hand, bonus, update_time) FROM stdin;
    public          postgres    false    203           �          0    16931    interest_category 
   TABLE DATA           r   COPY public.interest_category (id, desc_vn, desc_en, effective_date, "TYPE", active_yn, last_updated) FROM stdin;
    public          postgres    false    205           A           0    0    ORDER_SQ    SEQUENCE SET     9   SELECT pg_catalog.setval('public."ORDER_SQ"', 1, false);
          public          postgres    false    220            �
           2606    17097    CUSTOMER_INFO CLIENT_INFO_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public."CUSTOMER_INFO"
    ADD CONSTRAINT "CLIENT_INFO_pkey" PRIMARY KEY ("CUST_ID");
 L   ALTER TABLE ONLY public."CUSTOMER_INFO" DROP CONSTRAINT "CLIENT_INFO_pkey";
       public            postgres    false    206                       2606    17278    FEE_LIST FEE_LIST_PKEY 
   CONSTRAINT     ^   ALTER TABLE ONLY public."FEE_LIST"
    ADD CONSTRAINT "FEE_LIST_PKEY" PRIMARY KEY ("FEE_ID");
 D   ALTER TABLE ONLY public."FEE_LIST" DROP CONSTRAINT "FEE_LIST_PKEY";
       public            postgres    false    209                       2606    17372    FEE_SETTING FEE_SETTING1_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public."FEE_SETTING"
    ADD CONSTRAINT "FEE_SETTING1_pkey" PRIMARY KEY ("NAME_ID");
 K   ALTER TABLE ONLY public."FEE_SETTING" DROP CONSTRAINT "FEE_SETTING1_pkey";
       public            postgres    false    215            �
           2606    16950    FEE_CATEGORY FEE_SETTING_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY public."FEE_CATEGORY"
    ADD CONSTRAINT "FEE_SETTING_pkey" PRIMARY KEY ("FEE_ID");
 K   ALTER TABLE ONLY public."FEE_CATEGORY" DROP CONSTRAINT "FEE_SETTING_pkey";
       public            postgres    false    204                       2606    17266    LOAN_LIST LOAN_LIST_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public."LOAN_LIST"
    ADD CONSTRAINT "LOAN_LIST_pkey" PRIMARY KEY ("LOAN_ID");
 F   ALTER TABLE ONLY public."LOAN_LIST" DROP CONSTRAINT "LOAN_LIST_pkey";
       public            postgres    false    210                       2606    17268    LOAN_SETTING LOAN_SETTING_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public."LOAN_SETTING"
    ADD CONSTRAINT "LOAN_SETTING_pkey" PRIMARY KEY ("NAME_ID");
 L   ALTER TABLE ONLY public."LOAN_SETTING" DROP CONSTRAINT "LOAN_SETTING_pkey";
       public            postgres    false    211            	           2606    17270 "   MARGIN_SETTING MARGIN_SETTING_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public."MARGIN_SETTING"
    ADD CONSTRAINT "MARGIN_SETTING_pkey" PRIMARY KEY ("MARGIN_ID");
 P   ALTER TABLE ONLY public."MARGIN_SETTING" DROP CONSTRAINT "MARGIN_SETTING_pkey";
       public            postgres    false    212                       2606    17423    ORDER_DETAIL ORDER_DETAIL_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public."ORDER_DETAIL"
    ADD CONSTRAINT "ORDER_DETAIL_pkey" PRIMARY KEY ("SYS_ORDER_NO", "ORDER_SUB_NO");
 L   ALTER TABLE ONLY public."ORDER_DETAIL" DROP CONSTRAINT "ORDER_DETAIL_pkey";
       public            postgres    false    218    218                       2606    17418    ORDER ORDER_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public."ORDER"
    ADD CONSTRAINT "ORDER_pkey" PRIMARY KEY ("SYS_ORDER_NO");
 >   ALTER TABLE ONLY public."ORDER" DROP CONSTRAINT "ORDER_pkey";
       public            postgres    false    217                       2606    17402    PRODUCT_FEE PRODUCT_FEE1_pkey 
   CONSTRAINT     s   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_pkey" PRIMARY KEY ("PRODUCT_ID", "FEE_ID");
 K   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_pkey";
       public            postgres    false    216    216                       2606    17274    PRODUCT_LIST PRODUCT_LIST_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public."PRODUCT_LIST"
    ADD CONSTRAINT "PRODUCT_LIST_pkey" PRIMARY KEY ("PRODUCT_ID");
 L   ALTER TABLE ONLY public."PRODUCT_LIST" DROP CONSTRAINT "PRODUCT_LIST_pkey";
       public            postgres    false    213                       2606    17276 $   PRODUCT_SETTING PRODUCT_SETTING_pkey 
   CONSTRAINT     }   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_pkey" PRIMARY KEY ("PRODUCT_ID", "MARGIN_ID");
 R   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_pkey";
       public            postgres    false    214    214            �
           2606    17549    STOCK_INFO STOCK_INFO_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public."STOCK_INFO"
    ADD CONSTRAINT "STOCK_INFO_pkey" PRIMARY KEY ("STOCK_NO", "EXCHG_CD");
 H   ALTER TABLE ONLY public."STOCK_INFO" DROP CONSTRAINT "STOCK_INFO_pkey";
       public            postgres    false    202    202                       2606    17461 '   TEST_FEE_SETTING TEST_FEE_SETTING1_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public."TEST_FEE_SETTING"
    ADD CONSTRAINT "TEST_FEE_SETTING1_pkey" PRIMARY KEY ("NAME_ID");
 U   ALTER TABLE ONLY public."TEST_FEE_SETTING" DROP CONSTRAINT "TEST_FEE_SETTING1_pkey";
       public            postgres    false    219            �
           2606    17106    USER_AUTH USER_AUTH_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public."USER_AUTH"
    ADD CONSTRAINT "USER_AUTH_pkey" PRIMARY KEY ("LOGIN_UID", "CUST_ID");
 F   ALTER TABLE ONLY public."USER_AUTH" DROP CONSTRAINT "USER_AUTH_pkey";
       public            postgres    false    207    207                       2606    17138 "   client_cash_bal client_cash_bal_pk 
   CONSTRAINT     q   ALTER TABLE ONLY public.client_cash_bal
    ADD CONSTRAINT client_cash_bal_pk PRIMARY KEY (clientid, tradedate);
 L   ALTER TABLE ONLY public.client_cash_bal DROP CONSTRAINT client_cash_bal_pk;
       public            postgres    false    208    208            �
           2606    16875 $   client_stock_bal client_stock_bal_pk 
   CONSTRAINT     s   ALTER TABLE ONLY public.client_stock_bal
    ADD CONSTRAINT client_stock_bal_pk PRIMARY KEY (clientid, tradedate);
 N   ALTER TABLE ONLY public.client_stock_bal DROP CONSTRAINT client_stock_bal_pk;
       public            postgres    false    203    203            �
           2606    16938 &   interest_category interest_category_pk 
   CONSTRAINT     d   ALTER TABLE ONLY public.interest_category
    ADD CONSTRAINT interest_category_pk PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.interest_category DROP CONSTRAINT interest_category_pk;
       public            postgres    false    205                       2606    17373 &   FEE_SETTING FEE_SETTING1_fkey_FEE_LIST    FK CONSTRAINT     �   ALTER TABLE ONLY public."FEE_SETTING"
    ADD CONSTRAINT "FEE_SETTING1_fkey_FEE_LIST" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_LIST"("FEE_ID");
 T   ALTER TABLE ONLY public."FEE_SETTING" DROP CONSTRAINT "FEE_SETTING1_fkey_FEE_LIST";
       public          postgres    false    209    2819    215                       2606    17403 $   PRODUCT_FEE PRODUCT_FEE1_FEE_ID_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_FEE_ID_fkey" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_SETTING"("NAME_ID");
 R   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_FEE_ID_fkey";
       public          postgres    false    2831    215    216                       2606    17408 (   PRODUCT_FEE PRODUCT_FEE1_PRODUCT_ID_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_FEE"
    ADD CONSTRAINT "PRODUCT_FEE1_PRODUCT_ID_fkey" FOREIGN KEY ("PRODUCT_ID") REFERENCES public."PRODUCT_LIST"("PRODUCT_ID");
 V   ALTER TABLE ONLY public."PRODUCT_FEE" DROP CONSTRAINT "PRODUCT_FEE1_PRODUCT_ID_fkey";
       public          postgres    false    2827    216    213                       2606    17295 3   PRODUCT_SETTING PRODUCT_SETTING_MARGIN_SETTING_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_MARGIN_SETTING_fkey" FOREIGN KEY ("MARGIN_ID") REFERENCES public."MARGIN_SETTING"("MARGIN_ID");
 a   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_MARGIN_SETTING_fkey";
       public          postgres    false    214    2825    212                       2606    17300 1   PRODUCT_SETTING PRODUCT_SETTING_PRODUCT_LIST_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public."PRODUCT_SETTING"
    ADD CONSTRAINT "PRODUCT_SETTING_PRODUCT_LIST_fkey" FOREIGN KEY ("PRODUCT_ID") REFERENCES public."PRODUCT_LIST"("PRODUCT_ID");
 _   ALTER TABLE ONLY public."PRODUCT_SETTING" DROP CONSTRAINT "PRODUCT_SETTING_PRODUCT_LIST_fkey";
       public          postgres    false    214    2827    213                       2606    17462 0   TEST_FEE_SETTING TEST_FEE_SETTING1_fkey_FEE_LIST    FK CONSTRAINT     �   ALTER TABLE ONLY public."TEST_FEE_SETTING"
    ADD CONSTRAINT "TEST_FEE_SETTING1_fkey_FEE_LIST" FOREIGN KEY ("FEE_ID") REFERENCES public."FEE_LIST"("FEE_ID");
 ^   ALTER TABLE ONLY public."TEST_FEE_SETTING" DROP CONSTRAINT "TEST_FEE_SETTING1_fkey_FEE_LIST";
       public          postgres    false    2819    219    209                       2606    17425    ORDER_DETAIL order_detail_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ORDER_DETAIL"
    ADD CONSTRAINT order_detail_fk FOREIGN KEY ("SYS_ORDER_NO") REFERENCES public."ORDER"("SYS_ORDER_NO");
 H   ALTER TABLE ONLY public."ORDER_DETAIL" DROP CONSTRAINT order_detail_fk;
       public          postgres    false    218    217    2835                       2606    17107 &   USER_AUTH user_auth_fkey_customer_info    FK CONSTRAINT     �   ALTER TABLE ONLY public."USER_AUTH"
    ADD CONSTRAINT user_auth_fkey_customer_info FOREIGN KEY ("CUST_ID") REFERENCES public."CUSTOMER_INFO"("CUST_ID");
 R   ALTER TABLE ONLY public."USER_AUTH" DROP CONSTRAINT user_auth_fkey_customer_info;
       public          postgres    false    2813    206    207           