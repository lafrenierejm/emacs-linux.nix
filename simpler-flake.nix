{
  output = { ... }: {
    overlay = final: prev: {
      myEmacs = prev.emacsPgtkGcc.overrideAttrs (
        old: rec {
        }
      );
    };
  };
}
