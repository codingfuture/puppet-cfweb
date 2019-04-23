#
# Copyright 2019 (c) Andrey Galkin
#


type CfWeb::DockerImage = Struct[{
  image        => Optional[Pattern[/^[\S]*$/]],
  image_tag    => Optional[String],
  image_digest => Optional[String],
}]
