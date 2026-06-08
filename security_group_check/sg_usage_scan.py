#!/usr/bin/env python3

import argparse
import boto3
import json
import logging
import time
from datetime import datetime, timezone
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

from rich.console import Console
from rich.logging import RichHandler
from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeElapsedColumn
from rich.table import Table
from rich.panel import Panel


console = Console()
logger = logging.getLogger("sg-scanner")


SERVICE_DISPLAY_NAMES = {
    "ec2": "EC2 / Network Interfaces",
    "elbv2": "ALB / NLB",
    "elb": "Classic ELB",
    "rds": "RDS",
    "lambda": "Lambda",
    "elasticache": "ElastiCache",
    "redshift": "Redshift",
    "efs": "EFS",
    "opensearch": "OpenSearch",
    "msk": "MSK Kafka",
    "ecs": "ECS",
}


def setup_logging(verbose=False, log_file=None):
    level = logging.DEBUG if verbose else logging.INFO

    handlers = [
        RichHandler(
            console=console,
            rich_tracebacks=True,
            show_time=True,
            show_level=True,
            show_path=False,
        )
    ]

    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(level)
        file_handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(message)s")
        )
        handlers.append(file_handler)

    logging.basicConfig(
        level=level,
        format="%(message)s",
        handlers=handlers,
        force=True,
    )

    logging.getLogger("botocore.credentials").setLevel(logging.WARNING)
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)


def boto_session(region=None, profile=None):
    return boto3.Session(profile_name=profile, region_name=region)


def aws_client(service, region, profile=None):
    return boto_session(region, profile).client(service)


def add_result(results, service, resource_type, resource_id, name, region, sg_id, details=""):
    results.append({
        "service": service,
        "resource_type": resource_type,
        "resource_id": resource_id or "",
        "name": name or "",
        "region": region,
        "security_group_id": sg_id,
        "details": details or "",
    })


def add_error(errors, service, region, message):
    errors.append({
        "service": service,
        "region": region,
        "error": str(message),
    })


def paginate(client, operation, result_key, **kwargs):
    paginator = client.get_paginator(operation)
    for page in paginator.paginate(**kwargs):
        for item in page.get(result_key, []):
            yield item


def scan_ec2_enis(region, sg_id, profile, results, errors):
    service = "EC2/VPC"
    try:
        ec2 = aws_client("ec2", region, profile)

        for eni in paginate(
            ec2,
            "describe_network_interfaces",
            "NetworkInterfaces",
            Filters=[{"Name": "group-id", "Values": [sg_id]}],
        ):
            attachment = eni.get("Attachment", {})
            add_result(
                results,
                service,
                eni.get("InterfaceType", "network-interface"),
                eni.get("NetworkInterfaceId"),
                eni.get("Description"),
                region,
                sg_id,
                f"status={eni.get('Status')}, attached_to={attachment.get('InstanceId', '')}",
            )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_elbv2(region, sg_id, profile, results, errors):
    service = "ELBv2"
    try:
        elbv2 = aws_client("elbv2", region, profile)

        for lb in paginate(elbv2, "describe_load_balancers", "LoadBalancers"):
            if sg_id in lb.get("SecurityGroups", []):
                add_result(
                    results,
                    service,
                    lb.get("Type", "load-balancer"),
                    lb.get("LoadBalancerArn"),
                    lb.get("LoadBalancerName"),
                    region,
                    sg_id,
                    lb.get("DNSName", ""),
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_classic_elb(region, sg_id, profile, results, errors):
    service = "Classic ELB"
    try:
        elb = aws_client("elb", region, profile)

        for lb in paginate(elb, "describe_load_balancers", "LoadBalancerDescriptions"):
            if sg_id in lb.get("SecurityGroups", []):
                add_result(
                    results,
                    service,
                    "classic-load-balancer",
                    lb.get("LoadBalancerName"),
                    lb.get("LoadBalancerName"),
                    region,
                    sg_id,
                    lb.get("DNSName", ""),
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_rds(region, sg_id, profile, results, errors):
    service = "RDS"
    try:
        rds = aws_client("rds", region, profile)

        for db in paginate(rds, "describe_db_instances", "DBInstances"):
            groups = [g.get("VpcSecurityGroupId") for g in db.get("VpcSecurityGroups", [])]

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "db-instance",
                    db.get("DBInstanceIdentifier"),
                    db.get("DBInstanceIdentifier"),
                    region,
                    sg_id,
                    f"engine={db.get('Engine')}, status={db.get('DBInstanceStatus')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_lambda(region, sg_id, profile, results, errors):
    service = "Lambda"
    try:
        lam = aws_client("lambda", region, profile)

        for fn in paginate(lam, "list_functions", "Functions"):
            cfg = lam.get_function_configuration(FunctionName=fn["FunctionName"])
            groups = cfg.get("VpcConfig", {}).get("SecurityGroupIds", [])

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "function",
                    cfg.get("FunctionArn"),
                    cfg.get("FunctionName"),
                    region,
                    sg_id,
                    f"runtime={cfg.get('Runtime')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_elasticache(region, sg_id, profile, results, errors):
    service = "ElastiCache"
    try:
        ecache = aws_client("elasticache", region, profile)

        for cluster in paginate(
            ecache,
            "describe_cache_clusters",
            "CacheClusters",
            ShowCacheNodeInfo=False,
        ):
            groups = [g.get("SecurityGroupId") for g in cluster.get("SecurityGroups", [])]

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "cache-cluster",
                    cluster.get("CacheClusterId"),
                    cluster.get("CacheClusterId"),
                    region,
                    sg_id,
                    f"engine={cluster.get('Engine')}, status={cluster.get('CacheClusterStatus')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_redshift(region, sg_id, profile, results, errors):
    service = "Redshift"
    try:
        redshift = aws_client("redshift", region, profile)

        for cluster in paginate(redshift, "describe_clusters", "Clusters"):
            groups = [g.get("VpcSecurityGroupId") for g in cluster.get("VpcSecurityGroups", [])]

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "cluster",
                    cluster.get("ClusterIdentifier"),
                    cluster.get("ClusterIdentifier"),
                    region,
                    sg_id,
                    f"status={cluster.get('ClusterStatus')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_efs(region, sg_id, profile, results, errors):
    service = "EFS"
    try:
        efs = aws_client("efs", region, profile)

        for fs in paginate(efs, "describe_file_systems", "FileSystems"):
            for mt in paginate(
                efs,
                "describe_mount_targets",
                "MountTargets",
                FileSystemId=fs["FileSystemId"],
            ):
                sg_response = efs.describe_mount_target_security_groups(
                    MountTargetId=mt["MountTargetId"]
                )

                if sg_id in sg_response.get("SecurityGroups", []):
                    add_result(
                        results,
                        service,
                        "mount-target",
                        mt.get("MountTargetId"),
                        fs.get("Name") or fs.get("FileSystemId"),
                        region,
                        sg_id,
                        f"file_system={fs.get('FileSystemId')}",
                    )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_opensearch(region, sg_id, profile, results, errors):
    service = "OpenSearch"
    try:
        os_client = aws_client("opensearch", region, profile)

        for domain in os_client.list_domain_names().get("DomainNames", []):
            domain_name = domain.get("DomainName")
            details = os_client.describe_domain(DomainName=domain_name)
            status = details.get("DomainStatus", {})
            groups = status.get("VPCOptions", {}).get("SecurityGroupIds", [])

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "domain",
                    status.get("ARN"),
                    domain_name,
                    region,
                    sg_id,
                    f"engine_version={status.get('EngineVersion')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_msk(region, sg_id, profile, results, errors):
    service = "MSK"
    try:
        kafka = aws_client("kafka", region, profile)

        for cluster in paginate(kafka, "list_clusters_v2", "ClusterInfoList"):
            cluster_arn = cluster.get("ClusterArn")
            cluster_name = cluster.get("ClusterName")
            detail = kafka.describe_cluster_v2(ClusterArn=cluster_arn)

            info = detail.get("ClusterInfo", {})
            broker_info = info.get("Provisioned", {}).get("BrokerNodeGroupInfo", {})
            groups = broker_info.get("SecurityGroups", [])

            if sg_id in groups:
                add_result(
                    results,
                    service,
                    "cluster",
                    cluster_arn,
                    cluster_name,
                    region,
                    sg_id,
                    f"state={info.get('State')}",
                )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_ecs(region, sg_id, profile, results, errors):
    service = "ECS"
    try:
        ecs = aws_client("ecs", region, profile)

        clusters = list(paginate(ecs, "list_clusters", "clusterArns"))

        for cluster_arn in clusters:
            service_arns = list(
                paginate(
                    ecs,
                    "list_services",
                    "serviceArns",
                    cluster=cluster_arn,
                )
            )

            for i in range(0, len(service_arns), 10):
                batch = service_arns[i:i + 10]

                response = ecs.describe_services(
                    cluster=cluster_arn,
                    services=batch,
                )

                for svc in response.get("services", []):
                    groups = svc.get("networkConfiguration", {}).get(
                        "awsvpcConfiguration", {}
                    ).get("securityGroups", [])

                    if sg_id in groups:
                        add_result(
                            results,
                            service,
                            "service",
                            svc.get("serviceArn"),
                            svc.get("serviceName"),
                            region,
                            sg_id,
                            f"cluster={cluster_arn}, status={svc.get('status')}",
                        )

    except Exception as e:
        add_error(errors, service, region, e)


def scan_region(region, sg_id, profile, selected_services):
    results = []
    errors = []

    scanners = {
        "ec2": scan_ec2_enis,
        "elbv2": scan_elbv2,
        "elb": scan_classic_elb,
        "rds": scan_rds,
        "lambda": scan_lambda,
        "elasticache": scan_elasticache,
        "redshift": scan_redshift,
        "efs": scan_efs,
        "opensearch": scan_opensearch,
        "msk": scan_msk,
        "ecs": scan_ecs,
    }

    for name, scanner in scanners.items():
        if selected_services and name not in selected_services:
            continue

        display_name = SERVICE_DISPLAY_NAMES.get(name, name)
        logger.info(f"[{region}] Checking service: {display_name}")

        scanner(region, sg_id, profile, results, errors)

    return results, errors


def get_enabled_regions(profile=None):
    session = boto_session(profile=profile)
    ec2 = session.client("ec2")
    response = ec2.describe_regions(AllRegions=False)
    return [r["RegionName"] for r in response["Regions"]]


def print_results_table(results):
    if not results:
        console.print("[green]No resources found using this security group.[/green]")
        return

    table = Table(title="Security Group Usage Results", show_lines=True)

    table.add_column("Service", style="cyan", no_wrap=True)
    table.add_column("Type", style="magenta")
    table.add_column("Name", style="green")
    table.add_column("Resource ID", overflow="fold")
    table.add_column("Region", style="yellow")
    table.add_column("Details", overflow="fold")

    for r in results:
        table.add_row(
            r["service"],
            r["resource_type"],
            r["name"],
            r["resource_id"],
            r["region"],
            r["details"],
        )

    console.print(table)


def print_summary(results, errors, elapsed):
    summary = Counter(r["service"] for r in results)

    table = Table(title="Scan Summary")
    table.add_column("Item", style="cyan")
    table.add_column("Value", style="green")

    table.add_row("Resources found", str(len(results)))
    table.add_row("Services with matches", str(len(summary)))
    table.add_row("Errors / Skipped scans", str(len(errors)))
    table.add_row("Duration", f"{elapsed:.2f} seconds")

    console.print(table)

    if summary:
        svc_table = Table(title="Matches by Service")
        svc_table.add_column("Service", style="cyan")
        svc_table.add_column("Count", style="green")

        for service, count in summary.items():
            svc_table.add_row(service, str(count))

        console.print(svc_table)


def print_errors(errors):
    if not errors:
        return

    table = Table(title="Warnings / Skipped Scans", show_lines=True)
    table.add_column("Service", style="yellow")
    table.add_column("Region", style="cyan")
    table.add_column("Error", overflow="fold")

    for e in errors:
        table.add_row(e["service"], e["region"], e["error"])

    console.print(table)


def print_txt(results):
    if not results:
        print("No resources found using this security group.")
        return

    for r in results:
        print(f"[{r['region']}] {r['service']} - {r['resource_type']}")
        print(f"  Name    : {r['name']}")
        print(f"  ID      : {r['resource_id']}")
        print(f"  Details : {r['details']}")
        print()


def write_output_file(path, output_format, sg_id, results, errors, elapsed):
    payload = {
        "security_group_id": sg_id,
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "duration_seconds": elapsed,
        "result_count": len(results),
        "error_count": len(errors),
        "results": results,
        "errors": errors,
    }

    with open(path, "w", encoding="utf-8") as f:
        if output_format == "json":
            json.dump(payload, f, indent=2, default=str)
        else:
            f.write(f"Security Group: {sg_id}\n")
            f.write(f"Scanned At UTC: {payload['scanned_at']}\n")
            f.write(f"Duration: {elapsed:.2f} seconds\n")
            f.write(f"Results: {len(results)}\n")
            f.write(f"Errors: {len(errors)}\n\n")

            for r in results:
                f.write(f"[{r['region']}] {r['service']} - {r['resource_type']}\n")
                f.write(f"  Name    : {r['name']}\n")
                f.write(f"  ID      : {r['resource_id']}\n")
                f.write(f"  Details : {r['details']}\n\n")

    console.print(f"[green]Output written to:[/green] {path}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Scan AWS resources to find where a security group is used."
    )

    parser.add_argument("--sg-id", required=True)
    parser.add_argument("--region")
    parser.add_argument("--all-regions", action="store_true")
    parser.add_argument("--profile")
    parser.add_argument("--format", choices=["table", "json", "txt"], default="table")
    parser.add_argument("--output-file")
    parser.add_argument("--log-file", default="sg-usage-scanner.log")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--workers", type=int, default=5)

    parser.add_argument(
        "--services",
        nargs="+",
        choices=list(SERVICE_DISPLAY_NAMES.keys()),
        help="Optional services to scan",
    )

    return parser.parse_args()


def main():
    args = parse_args()
    setup_logging(args.verbose, args.log_file)

    start = time.time()

    console.print(
        Panel.fit(
            f"[bold cyan]AWS Security Group Usage Scanner[/bold cyan]\n"
            f"Security Group: [yellow]{args.sg_id}[/yellow]\n"
            f"Profile: [green]{args.profile or 'default credential chain'}[/green]",
            border_style="cyan",
        )
    )

    if args.all_regions:
        regions = get_enabled_regions(args.profile)
    else:
        region = args.region or boto_session(profile=args.profile).region_name
        if not region:
            raise SystemExit("Region not found. Use --region or configure region in your AWS profile.")
        regions = [region]

    logger.info(f"Regions to scan: {', '.join(regions)}")
    logger.info(f"Logs written to: {args.log_file}")

    all_results = []
    all_errors = []

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("{task.completed}/{task.total}"),
        TimeElapsedColumn(),
        console=console,
    ) as progress:

        task = progress.add_task("Scanning AWS regions", total=len(regions))

        if args.all_regions:
            with ThreadPoolExecutor(max_workers=args.workers) as executor:
                futures = {
                    executor.submit(
                        scan_region,
                        region,
                        args.sg_id,
                        args.profile,
                        args.services,
                    ): region
                    for region in regions
                }

                for future in as_completed(futures):
                    region = futures[future]

                    try:
                        results, errors = future.result()
                        all_results.extend(results)
                        all_errors.extend(errors)
                        logger.info(f"Completed region {region}: {len(results)} matches")
                    except Exception as e:
                        all_errors.append({
                            "service": "RegionScan",
                            "region": region,
                            "error": str(e),
                        })
                        logger.warning(f"Region failed {region}: {e}")

                    progress.advance(task)
        else:
            region = regions[0]
            results, errors = scan_region(
                region,
                args.sg_id,
                args.profile,
                args.services,
            )
            all_results.extend(results)
            all_errors.extend(errors)
            logger.info(f"Completed region {region}: {len(results)} matches")
            progress.advance(task)

    elapsed = time.time() - start

    if args.format == "json":
        print(json.dumps({
            "security_group_id": args.sg_id,
            "scanned_at": datetime.now(timezone.utc).isoformat(),
            "duration_seconds": elapsed,
            "result_count": len(all_results),
            "error_count": len(all_errors),
            "results": all_results,
            "errors": all_errors,
        }, indent=2, default=str))

    elif args.format == "txt":
        print_txt(all_results)

    else:
        print_results_table(all_results)
        print_summary(all_results, all_errors, elapsed)
        print_errors(all_errors)

    if args.output_file:
        file_format = "json" if args.output_file.endswith(".json") else "txt"
        write_output_file(
            args.output_file,
            file_format,
            args.sg_id,
            all_results,
            all_errors,
            elapsed,
        )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[yellow]Scan interrupted by user.[/yellow]")