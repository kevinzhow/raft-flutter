// Synthetic protocol-v2 catalog for the actual managed-agent form and native
// regression entry point. No runtime executable or external service is used.
const longModelForm = {
  'protocolVersion': 2,
  'runtimeId': 'opencode',
  'schemaVersion': 'opencode.scroll-fixture.v1',
  'dataSchema': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['model'],
    'properties': {
      'model': {
        'type': 'string',
        'title': 'Model',
        'minLength': 1,
        'x-optionSource': 'model',
      },
    },
  },
  'uiSchema': {
    'order': ['model'],
  },
  'optionSources': {
    'model': {
      'protocolVersion': 1,
      'runtimeId': 'opencode',
      'schemaVersion': 'opencode.scroll-fixture.v1',
      'sourceId': 'model',
      'kind': 'select',
      'pointer': '/model',
    },
  },
};

final longModelSource = {
  ...(longModelForm['optionSources'] as Map)['model'] as Map,
  'status': 'ready',
  'options': [
    for (var i = 0; i < 40; i++)
      {'value': 'fixture-model-$i', 'label': 'Fixture Model $i'},
  ],
  'defaultValue': 'fixture-model-0',
  'customValueAllowed': false,
};
