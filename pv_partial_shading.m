function pv_shading_app
%PV_SHADING_APP  Interactive PV partial-shading simulator (4S x 2P, 625 Wp).
%   Run:  pv_shading_app
%   Drag any of the 8 module sliders; I-V / P-V curves, MPPs and shading
%   loss update live. Needs R2018a+ (uifigure, uigridlayout). No toolboxes.

%% ---- Datasheet (STC) ----
DS.Pmax = 625;  DS.Voc = 48.73;  DS.Vmp = 41.19;
DS.Isc  = 15.97; DS.Imp = 15.18;
DS.G       = [0 200 400 600 800 1000];
DS.Isc_tbl = [0 3 6.3 9.5 12.87 15.97];
DS.Rs = 0.1;  DS.VB = 0.7;
DS.A  = fit_ideality(DS);

%% ---- State ----
Vmax = 200;
V    = linspace(0, Vmax, 641);
G    = 1000*ones(4,2);                 % rows = series position, cols = string
ref  = simulate(V, G, DS);
Pref = max(ref.P);

presets = struct( ...
    'name', {'No shading','One module at 400','Staircase on String 1', ...
             'Half of String 1 shaded','Heavy shade on M41'}, ...
    'G',    {1000*ones(4,2), ...
             [1000 1000; 1000 1000; 400 1000; 1000 1000], ...
             [1000 1000; 800 1000; 600 1000; 400 1000], ...
             [1000 1000; 1000 1000; 200 1000; 200 1000], ...
             [1000 1000; 1000 1000; 1000 1000; 0 1000]});

%% ---- UI ----
fig = uifigure('Name','PV Partial Shading Simulator - 4S x 2P', ...
               'Position',[80 60 1180 720], 'Color',[0.97 0.98 0.99]);
main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {300, '1x'};
main.Padding = [8 8 8 8];

% Left: sliders
left = uigridlayout(main, [8 2]);
left.RowHeight = {22, '1x','1x','1x','1x', 28, 28, 28};
left.Padding = [4 4 4 4];  left.RowSpacing = 6;
uilabel(left,'Text','String 1','FontWeight','bold','HorizontalAlignment','center');
uilabel(left,'Text','String 2','FontWeight','bold','HorizontalAlignment','center');

sld = gobjects(4,2);  pnl = gobjects(4,2);  lbl = gobjects(4,2);
for r = 1:4
    for c = 1:2
        pnl(r,c) = uipanel(left, 'Title', sprintf('M%d%d', r, c));
        g = uigridlayout(pnl(r,c), [2 1]);
        g.RowHeight = {18, '1x'};  g.Padding = [8 2 8 6];  g.RowSpacing = 2;
        lbl(r,c) = uilabel(g, 'Text', '', 'FontSize', 11);
        sld(r,c) = uislider(g, 'Limits',[0 1000], 'Value',1000, ...
                            'MajorTicks',[0 500 1000], 'MinorTicks',[]);
        sld(r,c).ValueChangingFcn = @(~,e) onSlide(r, c, e.Value);
        sld(r,c).ValueChangedFcn  = @(s,~) onSlide(r, c, s.Value, true);
    end
end

dd = uidropdown(left, 'Items', {'Custom', presets.name}, 'Value','Custom', ...
                'ValueChangedFcn', @onPreset);
dd.Layout.Row = 6;  dd.Layout.Column = [1 2];
btnAll = uibutton(left, 'Text','Set all to 1000 W/m²', 'ButtonPushedFcn', @(~,~) setAll(1000*ones(4,2)));
btnAll.Layout.Row = 7;  btnAll.Layout.Column = [1 2];
note = uilabel(left, 'Text','Series: M1 (top) to M4 (bottom).  Step 50 W/m².', ...
               'FontSize',10, 'FontColor',[0.45 0.47 0.53]);
note.Layout.Row = 8;  note.Layout.Column = [1 2];

% Right: stats + plots
right = uigridlayout(main, [4 1]);
right.RowHeight = {52, '1x', '1x', 26};  right.Padding = [4 4 4 4];
stats = uilabel(right, 'Text','', 'FontSize',14, 'FontWeight','bold', ...
                'WordWrap','on', 'VerticalAlignment','center');

axI = uiaxes(right);  axP = uiaxes(right);
peaksLbl = uilabel(right, 'Text','', 'FontSize',12, 'FontColor',[0.36 0.42 0.94]);

c1 = [0.263 0.380 0.933];  c2 = [0.902 0.224 0.275];  cp = [0.357 0.416 0.941];
gray = [0.75 0.75 0.78];

hold(axI,'on');  grid(axI,'on');
plot(axI, V, ref.IT, '--', 'Color', gray, 'DisplayName','No shading');
hI1 = plot(axI, V, nan(size(V)), 'Color', c1, 'LineWidth',1.6, 'DisplayName','String 1');
hI2 = plot(axI, V, nan(size(V)), 'Color', c2, 'LineWidth',1.6, 'DisplayName','String 2');
hIT = plot(axI, V, nan(size(V)), 'k', 'LineWidth',2.2, 'DisplayName','Total');
xlim(axI,[0 Vmax]);  ylim(axI,[0 35]);
xlabel(axI,'Array voltage (V)');  ylabel(axI,'Current (A)');
title(axI,'I-V characteristic');  legend(axI,'Location','northeast');

hold(axP,'on');  grid(axP,'on');
plot(axP, V, ref.P, '--', 'Color', gray);
hP  = plot(axP, V, nan(size(V)), 'Color', cp, 'LineWidth',2.2);
hPl = plot(axP, nan, nan, 'o', 'Color', cp, 'MarkerFaceColor','w', 'LineWidth',1.5, 'MarkerSize',7);
hPg = plot(axP, nan, nan, 'o', 'Color', cp, 'MarkerFaceColor', cp, 'MarkerSize',9);
xlim(axP,[0 Vmax]);  ylim(axP,[0 ceil(Pref*1.1/1000)*1000]);
xlabel(axP,'Array voltage (V)');  ylabel(axP,'Power (W)');
title(axP,'P-V characteristic  (filled = global MPP, hollow = local MPP)');

refresh();

%% ---- Callbacks ----
    function onSlide(r, c, val, snap)
        G(r,c) = min(1000, max(0, round(val/50)*50));
        if nargin > 3 && snap, sld(r,c).Value = G(r,c); end   % snap thumb on release
        dd.Value = 'Custom';
        refresh();
    end

    function onPreset(~,~)
        k = find(strcmp({presets.name}, dd.Value), 1);
        if ~isempty(k), setAll(presets(k).G, true); end
    end

    function setAll(Gnew, keepDropdown)
        G = Gnew;
        for rr = 1:4
            for cc = 1:2
                sld(rr,cc).Value = G(rr,cc);
            end
        end
        if nargin < 2 || ~keepDropdown, dd.Value = 'Custom'; end
        refresh();
    end

    function refresh()
        sim = simulate(V, G, DS);
        [Pm, gi] = max(sim.P);
        pk = find_mpp_peaks(V, sim.P);
        lc = pk(pk ~= gi);

        set(hI1,'YData',sim.I1);  set(hI2,'YData',sim.I2);  set(hIT,'YData',sim.IT);
        set(hP, 'YData',sim.P);
        set(hPl,'XData',V(lc), 'YData',sim.P(lc));
        set(hPg,'XData',V(gi), 'YData',Pm);

        Voc = V(find(sim.IT > 0.02, 1, 'last'));
        if isempty(Voc), Voc = 0; end
        loss = max(0, (1 - Pm/Pref)*100);
        stats.Text = sprintf(['Pmax %.0f W   |   Vmpp %.1f V   |   Impp %.2f A   |   ' ...
                              'Isc %.2f A   |   Voc %.1f V   |   Shading loss %.1f %%'], ...
                              Pm, V(gi), sim.IT(gi), sim.IT(1), Voc, loss);

        [~, ord] = sort(V(pk));  pk = pk(ord);
        parts = cell(1, numel(pk));
        for k = 1:numel(pk)
            tag = 'Local MPP';  if pk(k) == gi, tag = 'Global MPP'; end
            parts{k} = sprintf('%s: %.0f W @ %.1f V', tag, sim.P(pk(k)), V(pk(k)));
        end
        if numel(pk) <= 1, parts{end+1} = 'Single peak - no mismatch'; end
        peaksLbl.Text = strjoin(parts, '     ');

        for rr = 1:4
            for cc = 1:2
                lbl(rr,cc).Text = sprintf('%4d W/m²   Isc = %.2f A', ...
                                          G(rr,cc), isc_at(G(rr,cc), DS));
            end
        end
        drawnow limitrate;
    end
end

%% =================== Physics (same as pv_partial_shading.m) ===================

function a = fit_ideality(DS)
    a = fzero(@(a) vat_imp(a, DS), [0.5 9]);
end

function d = vat_imp(a, DS)
    e1 = exp(DS.Voc/a);  e2 = exp(DS.Isc*DS.Rs/a);
    i0  = max(DS.Isc/(e1 - e2), 1e-300);
    iph = i0*(e1 - 1);
    d = a*log((iph - DS.Imp)/i0 + 1) - DS.Imp*DS.Rs - DS.Vmp;
end

function isc = isc_at(g, DS)
    g = min(max(g, 0), DS.G(end));
    isc = interp1(DS.G, DS.Isc_tbl, g, 'linear');
end

function v = v_mod(I, g, DS)
    isc = isc_at(g, DS);
    v = zeros(size(I));
    if isc <= 1e-9
        v(I > 1e-9) = -DS.VB;
        return
    end
    eVoc = exp(DS.Voc/DS.A) - 1;
    iph  = isc/(1 - (exp(isc*DS.Rs/DS.A) - 1)/eVoc);
    i0g  = iph/eVoc;
    ok = I < isc;
    v(~ok) = -DS.VB;
    v(ok)  = max(DS.A*log((iph - I(ok))/i0g + 1) - I(ok)*DS.Rs, -DS.VB);
end

function v = v_str(I, gs, DS)
    v = zeros(size(I));
    for k = 1:numel(gs)
        v = v + v_mod(I, gs(k), DS);
    end
end

function I = i_str(V, gs, DS)
    imax = isc_at(max(gs), DS);
    I = zeros(size(V));
    if imax <= 1e-9, return, end
    v0    = v_str(0, gs, DS);
    vImax = v_str(imax, gs, DS);
    lo = zeros(size(V));  hi = imax*ones(size(V));
    for it = 1:45
        m  = (lo + hi)/2;
        up = v_str(m, gs, DS) > V;
        lo(up)  = m(up);
        hi(~up) = m(~up);
    end
    I = (lo + hi)/2;
    I(V >= v0)    = 0;
    I(V <= vImax) = imax;
end

function out = simulate(V, G, DS)
    out.I1 = i_str(V, G(:,1), DS);
    out.I2 = i_str(V, G(:,2), DS);
    out.IT = out.I1 + out.I2;
    out.P  = V .* out.IT;
end

function idx = find_mpp_peaks(V, P)
    pmax = max(P);  thr = max(0.015*pmax, 5);
    idx = [];  cand = 1;  mode = 'up';  minV = P(1);
    for k = 2:numel(P)
        p = P(k);
        if strcmp(mode, 'up')
            if p > P(cand)
                cand = k;
            elseif P(cand) - p > thr
                idx(end+1) = cand;  mode = 'down';  minV = p; %#ok<AGROW>
            end
        else
            if p < minV
                minV = p;
            elseif p - minV > thr
                mode = 'up';  cand = k;
            end
        end
    end
    if strcmp(mode,'up') && P(cand) > thr && V(cand) < 198 && P(cand) - P(end) > thr
        idx(end+1) = cand;
    end
    if isempty(idx), [~, idx] = max(P); end
    idx = idx(P(idx) > 0.02*pmax);
    if isempty(idx), [~, idx] = max(P); end
end