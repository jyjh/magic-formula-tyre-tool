function collapseButtonTextOnResize(width, buttonsGrid, ...
    columnWidthWithText, columnWidthOnlyIcon, texts)
%COLLAPSEBUTTONTEXTONRESIZE Toggle button text vs icon-only based on the
%width available to the grid. When the with-text layout no longer fits,
%blank every button's text and switch the grid to the icon-only column
%widths; otherwise restore the original texts and widths.
%
%This consolidates the resize handler that was duplicated (with a
%known-buggy slow for-loop) across the three top-level panels.
arguments
    width (1,1) double
    buttonsGrid matlab.ui.container.GridLayout
    columnWidthWithText cell
    columnWidthOnlyIcon cell
    texts cell
end
buttons = buttonsGrid.Children;
buttonWidths = columnWidthWithText(cellfun(@isnumeric, columnWidthWithText));
minWidthButtonsWithText = sum([buttonWidths{:}]) ...
    + (numel(buttons)+2)*buttonsGrid.ColumnSpacing;
removeTextFromButtons = width < minWidthButtonsWithText;
if removeTextFromButtons
    set(buttons, 'Text', '')
    set(buttonsGrid, 'ColumnWidth', columnWidthOnlyIcon);
else
    for i = 1:numel(buttons)
        buttons(i).Text = texts{i};
    end
    set(buttonsGrid, 'ColumnWidth', columnWidthWithText);
end
end
