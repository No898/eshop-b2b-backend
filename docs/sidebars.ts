import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'intro',
    {
      type: 'category',
      label: 'GraphQL API',
      items: [
        'api/graphql',
        'api/queries',
        'api/mutations',
        'api/types',
        'api/variants',
        'api/bulk-pricing',
        'api/addresses',
      ],
    },
    {
      type: 'category',
      label: 'React komponenty',
      items: [
        'components/products',
        'components/variants',
        'components/bulk-pricing',
        'components/addresses',
        'components/forms',
      ],
    },
    {
      type: 'category',
      label: 'Návody',
      items: [
        'guides/setup',
        'guides/authentication',
        'guides/deployment',
        'guides/testing',
      ],
    },
    {
      type: 'category',
      label: 'Examples',
      items: [
        'examples/basic-queries',
        'examples/variant-management',
        'examples/bulk-ordering',
        'examples/address-forms',
      ],
    },
  ],
};

export default sidebars;
