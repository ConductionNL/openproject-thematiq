// The attribute on <html> that says the plugin's frontend module runs in this bundle.
export const LINKED_ATTRIBUTE = 'data-thematiq-frontend';

export function markLinked(doc:Document):void {
  doc.documentElement.setAttribute(LINKED_ATTRIBUTE, 'linked');
}
