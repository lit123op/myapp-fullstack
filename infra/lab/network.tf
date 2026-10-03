resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = local.subnet_cidrs.public[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${local.name}-public-${count.index + 1}" })
}

resource "aws_subnet" "ecs" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = local.subnet_cidrs.ecs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${local.name}-private-ecs-${count.index + 1}" })
}

resource "aws_subnet" "db" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = local.subnet_cidrs.db[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${local.name}-isolated-db-${count.index + 1}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.tags, { Name = "${local.name}-nat-eip" })
}

# Deliberate lab cost trade-off: one NAT only; egress is not highly available.
resource "aws_nat_gateway" "lab" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.public[0].id
  connectivity_type = "public"

  tags = merge(local.tags, { Name = "${local.name}-nat-single-az-not-ha" })

  depends_on = [aws_internet_gateway.lab]
}

resource "aws_route_table" "ecs" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.tags, { Name = "${local.name}-private-ecs-rt" })
}

resource "aws_route" "ecs_nat_egress" {
  route_table_id         = aws_route_table.ecs.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab.id
}

resource "aws_route_table_association" "ecs" {
  count          = 2
  subnet_id      = aws_subnet.ecs[count.index].id
  route_table_id = aws_route_table.ecs.id
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.tags, { Name = "${local.name}-isolated-db-rt" })
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

resource "aws_db_subnet_group" "lab" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id

  tags = merge(local.tags, { Name = "${local.name}-db-subnets" })
}