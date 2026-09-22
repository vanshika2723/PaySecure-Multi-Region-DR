data "aws_availability_zones" "available" {
state = "available"
}

resource "aws_vpc" "this" {
cidr_block           = var.vpc_cidr
enable_dns_support   = true
enable_dns_hostnames = true

tags = merge(
var.common_tags,
{
Name        = "${var.project_name}-${var.environment}-vpc"
Environment = var.environment
}
)
}

resource "aws_internet_gateway" "this" {
vpc_id = aws_vpc.this.id

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-igw"
}
)
}

resource "aws_subnet" "public" {
count = length(var.availability_zones)

vpc_id                  = aws_vpc.this.id
cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
availability_zone       = var.availability_zones[count.index]
map_public_ip_on_launch = true

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
Tier = "public"
}
)
}

resource "aws_subnet" "private" {
count = length(var.availability_zones)

vpc_id            = aws_vpc.this.id
cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
availability_zone = var.availability_zones[count.index]

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
Tier = "private"
}
)
}

resource "aws_subnet" "database" {
count = length(var.availability_zones)

vpc_id            = aws_vpc.this.id
cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
availability_zone = var.availability_zones[count.index]

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-database-${count.index + 1}"
Tier = "database"
}
)
}

resource "aws_eip" "nat" {
count  = length(var.availability_zones)
domain = "vpc"

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
}
)
}

resource "aws_nat_gateway" "this" {
count = length(var.availability_zones)

allocation_id = aws_eip.nat[count.index].id
subnet_id     = aws_subnet.public[count.index].id

depends_on = [
aws_internet_gateway.this
]

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
}
)
}

resource "aws_route_table" "public" {
vpc_id = aws_vpc.this.id

route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.this.id
}

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-public-rt"
}
)
}

resource "aws_route_table_association" "public" {
count = length(var.availability_zones)

subnet_id      = aws_subnet.public[count.index].id
route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
count = length(var.availability_zones)

vpc_id = aws_vpc.this.id

route {
cidr_block     = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.this[count.index].id
}

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
}
)
}

resource "aws_route_table_association" "private" {
count = length(var.availability_zones)

subnet_id      = aws_subnet.private[count.index].id
route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "database" {
count = length(var.availability_zones)

vpc_id = aws_vpc.this.id

tags = merge(
var.common_tags,
{
Name = "${var.project_name}-${var.environment}-database-rt-${count.index + 1}"
}
)
}

resource "aws_route_table_association" "database" {
count = length(var.availability_zones)

subnet_id      = aws_subnet.database[count.index].id
route_table_id = aws_route_table.database[count.index].id
}
