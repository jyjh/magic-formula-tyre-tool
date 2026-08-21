function width = figureContentWidth(component)
%FIGURECONTENTWIDTH Width available to a component by walking up to the
%non-grid ancestor (the figure or a panel). Components laid out inside a
%uigridlayout need the ancestor's width, not their own, to decide whether
%their button row still fits with text labels.
arguments
    component (1,1) handle
end
parent = component.Parent;
while isa(parent, 'matlab.ui.container.GridLayout')
    parent = parent.Parent;
end
width = parent.Position(3);
end
