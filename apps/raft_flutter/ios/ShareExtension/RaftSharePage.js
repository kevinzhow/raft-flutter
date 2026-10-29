// Public Safari extension preprocessing: only the shared page URL and title.
var ExtensionPreprocessingJS = {
  run: function(args) {
    args.completionFunction({url: document.baseURI, title: document.title});
  }
};
