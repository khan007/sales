﻿function initializeUI() {
    const template = `<div class="one summary items">
                            <div class="terms item">
                                <div class ="description">${window.translate("TermsAndConditions")}</div>
                                <div class="control">
                                    <textarea id="TermsTextArea" type="text"></textarea>
                                </div>
                            </div>
                        </div>
                        <div class="one summary items">
                            <div class="terms item">
                                <div class ="description">${window.translate("InternalMemo")}</div>
                                <div class="control">
                                    <textarea id="InternalMemoTextArea" type="text"></textarea>
                                </div>
                            </div>
                        </div>`;

    $(".page.title").html("Sales Quotation");

    const expectedDeliveryDate =
        $("<input type='text' class='date' value='7d' id='ExpectedDeliveryDateInputText' />");
    $("#BookDateInputDate").after(expectedDeliveryDate).remove();
    expectedDeliveryDate.parent().parent().find(".description").html(window.translate("ExpectedDeliveryDate"));

    $("#StatementReferenceInputText").closest(".two.summary.items").attr("class", "one summary items")
        .after(template);

    $(".memo.item").remove();
    $("#CostCenterSelect").closest(".two.summary.items").attr("class", "one summary items");
    $(".cost.center.item").remove();
    $(".store.item").remove();

    window.loadDatepicker();
};

initializeUI();

function getModel() {
    function getDetails() {
        const items = $("#SalesItems .item");
        var model = [];

        $.each(items, function () {
            const el = $(this);
            const itemId = window.parseInt(el.attr("data-item-id"));
            const quantity = window.parseFloat2(el.find("input.quantity").val());
            const unitId = window.parseInt(el.find("select.unit").val());
            const price = window.parseFloat2(el.find("input.price").val()) || 0;
            const discountRate = window.parseFloat2(el.find("input.discount").val()) || 0;
            const isTaxableItem = el.attr("data-is-taxable-item") === "true";
            const amount = price * quantity;
            const discount = window.round(amount * discountRate / 100, 2);

            model.push({
                ValueDate: $("#ValueDateInputDate").datepicker("getDate"),
                ItemId: itemId,
                Quantity: quantity,
                UnitId: unitId,
                Price: price,
                DiscountRate: discountRate,
                Discount: discount,
                IsTaxed: isTaxableItem
            });
        });

        return model;
    };

    const valueDate = $("#ValueDateInputDate").datepicker("getDate");
    const expectedDeliveryDate = $("#ExpectedDeliveryDateInputText").datepicker("getDate");
    const referenceNumber = $("#ReferenceNumberInputText").val();
    const terms = $("#TermsTextArea").val();
    const internalMemo = $("#InternalMemoTextArea").val();
    const customerId = $("#CustomerSelect").val();
    const priceTypeId = $("#PriceTypeSelect").val();
    const shipperId = $("#ShipperSelect").val();
    const details = getDetails();
    const discount = window.parseFloat2($("#DiscountInputText").val());
    var taxRate = window.parseFloat($("#SalesTaxRateHidden").val()) || 0;
    
    var totalPrice = 0;
    var taxableTotal = 0;
    var nonTaxableTotal = 0;
    var totalBeforeDiscount = 0;
    var tax = 0;

    (function(){
        const items = $("#SalesItems .item");

        $.each(items, function () {
            const el = $(this);
            const itemId = window.parseInt(el.attr("data-item-id"));
            const quantity = window.parseFloat2(el.find("input.quantity").val());
            const unitId = window.parseInt(el.find("select.unit").val());
            const price = window.parseFloat2(el.find("input.price").val()) || 0;
            const discountRate = window.parseFloat2(el.find("input.discount").val()) || 0;
            const isTaxableItem = el.attr("data-is-taxable-item") === "true";
            var discount = 0;
            const amount = price * quantity;
            const discountedAmount = amount * ((100 - discountRate) / 100);

            if (isTaxableItem) {
                taxableTotal += discountedAmount;
            } else {
                nonTaxableTotal += discountedAmount;
            };

            totalPrice += discountedAmount;
        });

        taxableTotal = window.round(taxableTotal, 2);
        nonTaxableTotal = window.round(nonTaxableTotal, 2);

        totalBeforeDiscount = taxableTotal;
        totalPrice -= discount;
        taxableTotal -= discount;

        tax = taxableTotal * (taxRate / 100);
        totalPrice += tax;

        totalPrice = window.round(totalPrice, 2);
    })();

    return {
        ValueDate: valueDate,
        ExpectedDeliveryDate: expectedDeliveryDate,
        ReferenceNumber: referenceNumber,
        Terms: terms,
        InternalMemo: internalMemo,
        CustomerId: customerId,
        PriceTypeId: priceTypeId,
        ShipperId: shipperId,
        Details: details,
        TaxableTotal: totalBeforeDiscount,
        Discount: discount,
        NonTaxableTotal: nonTaxableTotal,
        TaxRate: taxRate,
        Tax: tax
    };
};

$("#CheckoutButton").off("click").on("click", function () {
    function request(model) {
        const url = "/dashboard/sales/tasks/quotation/new";
        const data = JSON.stringify(model);
        return window.getAjaxRequest(url, "POST", data);
    };


    const model = getModel();

    if (!model.Details.length) {
        alert(window.translate("PleaseSelectItem"));
        return;
    };

    const confirmed = confirm(window.translate("AreYouSure"));

    if (!confirmed) {
        return;
    };


    $("#CheckoutButton").addClass("loading").prop("disabled", true);

    const ajax = request(model);

    ajax.success(function (response) {
        const id = response;
        document.location = `/dashboard/sales/tasks/quotation/checklist/${id}`;
    });

    ajax.fail(function (xhr) {
        $("#CheckoutButton").removeClass("loading").prop("disabled", false);
        window.logAjaxErrorMessage(xhr);
    });
});

window.overridePath = "/dashboard/sales/tasks/quotation";
