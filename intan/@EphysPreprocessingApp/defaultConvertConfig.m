function cfg = defaultConvertConfig(~)
    % Convert-tab defaults = the pipeline config's Signals section
    % (EphysPipelineConfig.defaults("Signals")), so the tab and a headless
    % run start from the same values. The section also carries Enabled,
    % ExcludeHandling and IncludeBehavior, which the tab does not show yet.
    cfg = EphysPipelineConfig.defaults("Signals");
end
