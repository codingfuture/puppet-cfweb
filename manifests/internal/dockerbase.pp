#
# Copyright 2019 (c) Andrey Galkin
#


class cfweb::internal::dockerbase(
    Hash $options,
) {
    create_resources('class', { 'docker' => $options })
}
