# Evidence copies

Historical test logs and review reports describe the source and tools recorded in
each report. They do not establish that a later release candidate passed those
checks. See [release status](release-status.md) for the current boundary.

Public copies of the October 22–27 implementation and playtest records have local
workstation paths and internal hostnames replaced with relative paths or generic
labels. This includes the JSON and compressed JSON review reports under
`story-reset-20261025`, `playtest-review`, `playtest-polish-20261026` and
`dialogue-pause-20261026`, and the latter's `first-runtime-pass.tar.gz` archive.
Archive owner metadata was also normalized. Test outcomes, counts, grouping and
classifications were preserved. Text logs identify the normalization in a header.

These copies have different byte hashes from the originals. Original evidence is
retained privately; a digest recorded before normalization identifies the original
artifact, not the public copy. Use current release manifests to verify distributed
package bytes.

Historical commit IDs in these records may refer to the repository before its
private-planning cleanup. They are evidence references, not current release IDs.

The November 2 release-preparation pass also replaces internal project aliases in public Markdown with their roles (reference prototype, local voice runtime, workflow automation). Original evidence and the alias mapping remain in the private audit backup. These are editorial redactions, not changed test outcomes or dependency licenses.
