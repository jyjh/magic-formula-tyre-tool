function applySidebarLayout(sidebar, axes, show)
%APPLYSIDEBARLAYOUT Show or hide a plot-panel sidebar. When hidden, the
%axes expand into the freed column.
if show
    set(sidebar, 'Visible', 'on')
    axes.Layout.Column = 1;
else
    set(sidebar, 'Visible', 'off')
    axes.Layout.Column = [1 2];
end
end
