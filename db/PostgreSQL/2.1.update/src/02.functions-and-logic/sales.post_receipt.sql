﻿DROP FUNCTION IF EXISTS sales.post_receipt
(
    _user_id                                    integer, 
    _office_id                                  integer, 
    _login_id                                   bigint,
    
    _customer_id                                integer,
    _currency_code                              national character varying(12), 
    _exchange_rate_debit                        public.decimal_strict, 

    _exchange_rate_credit                       public.decimal_strict,
    _reference_number                           national character varying(24), 
    _statement_reference                        text, 

    _cost_center_id                             integer,
    _cash_account_id                            integer,
    _cash_repository_id                         integer,

    _value_date                                 date,
    _book_date                                  date,
    _receipt_amount                             public.money_strict,

    _tender                                     public.money_strict2,
    _change                                     public.money_strict2,
    _check_amount                               public.money_strict2,

    _check_bank_name                            national character varying(1000),
    _check_number                               national character varying(100),
    _check_date                                 date,

    _gift_card_number                           national character varying(100),
    _store_id                                   integer,
    _cascading_tran_id                          bigint
);

CREATE FUNCTION sales.post_receipt
(
    _user_id                                    integer, 
    _office_id                                  integer, 
    _login_id                                   bigint,
    
    _customer_id                                integer,
    _currency_code                              national character varying(12), 
    _exchange_rate_debit                        public.decimal_strict, 

    _exchange_rate_credit                       public.decimal_strict,
    _reference_number                           national character varying(24), 
    _statement_reference                        text, 

    _cost_center_id                             integer,
    _cash_account_id                            integer,
    _cash_repository_id                         integer,

    _value_date                                 date,
    _book_date                                  date,
    _receipt_amount                             public.money_strict,

    _tender                                     public.money_strict2,
    _change                                     public.money_strict2,

    _check_amount                               public.money_strict2,
    _check_bank_name                            national character varying(1000),
    _check_number                               national character varying(100),
    _check_date                                 date,

    _gift_card_number                           national character varying(100),
    _store_id                                   integer DEFAULT NULL,
    _cascading_tran_id                          bigint DEFAULT NULL
)
RETURNS bigint
AS
$$
    DECLARE _book                               text;
    DECLARE _transaction_master_id              bigint;
    DECLARE _base_currency_code                 national character varying(12);
    DECLARE _local_currency_code                national character varying(12);
    DECLARE _customer_account_id                integer;
    DECLARE _debit                              public.money_strict2;
    DECLARE _credit                             public.money_strict2;
    DECLARE _lc_debit                           public.money_strict2;
    DECLARE _lc_credit                          public.money_strict2;
    DECLARE _is_cash                            boolean;
    DECLARE _gift_card_id                       integer;
    DECLARE _receivable_account_id              integer;
BEGIN
    IF NOT finance.can_post_transaction(_login_id, _user_id, _office_id, _book, _value_date) THEN
        RETURN 0;
    END IF;

    IF(_cash_repository_id > 0 AND _cash_account_id > 0) THEN
        _is_cash                            := true;
    END IF;

    _receivable_account_id                  := sales.get_receivable_account_for_check_receipts(_store_id);
    _gift_card_id                           := sales.get_gift_card_id_by_gift_card_number(_gift_card_number);
    _customer_account_id                    := inventory.get_account_id_by_customer_id(_customer_id);    
    _local_currency_code                    := core.get_currency_code_by_office_id(_office_id);
    _base_currency_code                     := inventory.get_currency_code_by_customer_id(_customer_id);


    IF(_local_currency_code = _currency_code AND _exchange_rate_debit != 1) THEN
        RAISE EXCEPTION 'Invalid exchange rate.'
        USING ERRCODE='P3055';
    END IF;

    IF(_base_currency_code = _currency_code AND _exchange_rate_credit != 1) THEN
        RAISE EXCEPTION 'Invalid exchange rate.'
        USING ERRCODE='P3055';
    END IF;

    --raise exception     '%', _cash_account_id;

    
    IF(_tender >= _receipt_amount) THEN
        _transaction_master_id              := sales.post_cash_receipt(_user_id, _office_id, _login_id, _customer_id, _customer_account_id, _currency_code, _local_currency_code, _base_currency_code, _exchange_rate_debit, _exchange_rate_credit, _reference_number, _statement_reference, _cost_center_id, _cash_account_id, _cash_repository_id, _value_date, _book_date, _receipt_amount, _tender, _change, _cascading_tran_id);
    ELSIF(_check_amount >= _receipt_amount) THEN
        _transaction_master_id              := sales.post_check_receipt(_user_id, _office_id, _login_id, _customer_id, _customer_account_id, _receivable_account_id, _currency_code, _local_currency_code, _base_currency_code, _exchange_rate_debit, _exchange_rate_credit, _reference_number, _statement_reference, _cost_center_id, _value_date, _book_date, _check_amount, _check_bank_name, _check_number, _check_date, _cascading_tran_id);
    ELSIF(_gift_card_id > 0) THEN
        _transaction_master_id              := sales.post_receipt_by_gift_card(_user_id, _office_id, _login_id, _customer_id, _customer_account_id, _currency_code, _local_currency_code, _base_currency_code, _exchange_rate_debit, _exchange_rate_credit, _reference_number, _statement_reference, _cost_center_id, _value_date, _book_date, _gift_card_id, _gift_card_number, _receipt_amount, _cascading_tran_id);
    ELSE
        RAISE EXCEPTION 'Cannot post receipt. Please enter the tender amount.';    
    END IF;

    
    PERFORM finance.auto_verify(_transaction_master_id, _office_id);
    PERFORM sales.settle_customer_due(_customer_id, _office_id);
    RETURN _transaction_master_id;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM sales.post_receipt(1, 1, 1,inventory.get_customer_id_by_customer_code('APP'), 'USD', 1, 1, '', '', 1, 1, 1, '1-1-2020', '1-1-2020', 100, 0, 1000, '', '', null, '', null);
--SELECT * FROM sales.post_receipt(1,1,1,inventory.get_customer_id_by_customer_code('DEF'),'USD',1,1,'','', 1, 1, 1, '1-1-2020', '1-1-2020', 2000, 0, 0, 0, '', '', null, '123456', 1, null);
